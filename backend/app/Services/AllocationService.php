<?php

namespace App\Services;

use App\Models\Driver;
use App\Models\Trip;
use App\Models\Vehicle;
use App\Models\VehicleRequest;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Three rules from the capstone (Chapter III):
 * 1. Driver availability  2. Vehicle readiness  3. Assignment conflicts
 *
 * Availability is checked by DATE. A vehicle or driver is unavailable when another
 * scheduled or in-progress trip overlaps any day of the trip being assigned
 * (a multi-day trip uses its whole date range).
 *
 * When an ACTIVE trip is reassigned, the vehicle or driver that is not being
 * replaced is not checked for "readiness" again. They are already marked
 * in use because of their own trip.
 */
class AllocationService
{
    /** Trip statuses that block double-booking. */
    public const ACTIVE = ['scheduled', 'in_progress'];

    /** Shape of an approved request in the allocation dropdown. */
    public static function requestOption(VehicleRequest $r): array
    {
        $tripDate = $r->trip_date->toDateString();

        return [
            'id' => $r->id,
            'label' => "#{$r->id} · {$r->destination} · {$tripDate} " . substr((string) $r->departure_time, 0, 5),
            'destination' => $r->destination,
            'purpose' => $r->purpose,
            'requester' => $r->requester?->full_name,
            'trip_date' => $tripDate,
            'trip_end_date' => $r->trip_end_date?->toDateString(),
            'trip_type' => $r->trip_type,
            'departure_time' => $r->departure_time,
            'estimated_return_time' => $r->estimated_return_time,
            'passengers' => $r->passengers,
            'number_of_passengers' => $r->number_of_passengers,
        ];
    }

    /**
     * Shape of a vehicle in the dropdown (and in the quick-add response).
     * $unavailableReason is set when the vehicle cannot be assigned on the chosen dates.
     */
    public static function vehicleOption(Vehicle $v, ?string $unavailableReason = null): array
    {
        return [
            'id' => $v->id,
            'label' => "{$v->plate_number} — {$v->vehicle_model}" . ($v->capacity ? " ({$v->capacity} seats)" : ''),
            'vehicle_model' => $v->vehicle_model,
            'plate_number' => $v->plate_number,
            'capacity' => $v->capacity,
            'available' => $unavailableReason === null,
            'unavailable_reason' => $unavailableReason,
        ];
    }

    /** Shape of a driver in the dropdown: name and contact number. */
    public static function driverOption(Driver $d, ?string $unavailableReason = null): array
    {
        $name = $d->full_name ?: "Driver #{$d->id}";
        $expiry = $d->license_expiry_date;

        return [
            'id' => $d->id,
            'label' => $name
                . ($d->contact_number ? " · {$d->contact_number}" : '')
                . ($expiry ? ' (Lic. exp. ' . $expiry->format('M Y') . ')' : ''),
            'name' => $name,
            'contact_number' => $d->contact_number,
            'license_expiry_date' => $expiry?->toDateString(),
            'available' => $unavailableReason === null,
            'unavailable_reason' => $unavailableReason,
        ];
    }

    /**
     * Marks every trip whose return time has passed as completed, and frees its vehicle and driver.
     *
     * The end of a trip is the END date of its request plus the estimated return time,
     * so a multi-day trip is not completed on its first day.
     * A trip with no estimated return time is left alone, because its end is not known.
     *
     * There is no scheduler. This runs when a page loads or is refreshed
     * (allocation list and trip schedule).
     *
     * @return int number of trips that were completed
     */
    public function completeFinishedTrips(): int
    {
        $now = now();

        $finished = Trip::with('vehicleRequest')
            ->whereIn('trip_status', self::ACTIVE)
            ->whereNotNull('estimated_return_time')
            ->whereDate('trip_date', '<=', $now->toDateString())
            ->get()
            ->filter(function (Trip $trip) use ($now) {
                $endDate = $trip->vehicleRequest?->trip_end_date ?? $trip->trip_date;
                $end = Carbon::parse($endDate->toDateString() . ' ' . $trip->estimated_return_time);

                return $end->lte($now);
            });

        if ($finished->isEmpty()) {
            return 0;
        }

        DB::transaction(function () use ($finished) {
            Trip::whereIn('id', $finished->pluck('id'))->update(['trip_status' => 'completed']);

            foreach ($finished as $trip) {
                $this->freeVehicleAndDriver((int) $trip->vehicle_id, (int) $trip->driver_id);
            }
        });

        return $finished->count();
    }

    /**
     * Frees a vehicle and a driver, unless another active trip still uses them.
     * Only an "in use" vehicle is reset, so a vehicle under maintenance keeps its status.
     */
    protected function freeVehicleAndDriver(int $vehicleId, int $driverId): void
    {
        $stillUsed = fn (string $column, int $id) => Trip::where($column, $id)
            ->whereIn('trip_status', self::ACTIVE)
            ->exists();

        if (! $stillUsed('vehicle_id', $vehicleId)) {
            Vehicle::where('id', $vehicleId)->where('status', 'in_use')->update(['status' => 'available']);
        }

        if (! $stillUsed('driver_id', $driverId)) {
            Driver::where('id', $driverId)->update(['is_available' => true, 'assigned_vehicle_id' => null]);
        }
    }

    /**
     * The first and last day of a request's trip.
     * When $newDate is given, the whole range is moved so it starts on that date.
     *
     * @return array{0: string, 1: string} [start, end] as YYYY-MM-DD
     */
    public function tripRange(VehicleRequest $vehicleRequest, ?string $newDate = null): array
    {
        $start = Carbon::parse($vehicleRequest->trip_date)->toDateString();
        $end = Carbon::parse($vehicleRequest->trip_end_date ?? $vehicleRequest->trip_date)->toDateString();

        if ($newDate) {
            $shift = (int) Carbon::parse($start)->diffInDays(Carbon::parse($newDate), false);
            $end = Carbon::parse($end)->addDays($shift)->toDateString();
            $start = $newDate;
        }

        return [$start, $end];
    }

    /**
     * Move the date of a SCHEDULED trip (and of its vehicle request).
     * First checks that the current vehicle and driver are free on the new dates.
     *
     * @return string the old date (YYYY-MM-DD)
     */
    public function moveTrip(Trip $trip, string $newDate): string
    {
        if ($trip->trip_status !== 'scheduled') {
            throw ValidationException::withMessages([
                'new_date' => "Only scheduled trips can have their date changed (this trip is {$trip->trip_status}).",
            ]);
        }

        $old = Carbon::parse($trip->trip_date)->toDateString();

        if ($newDate === $old) {
            throw ValidationException::withMessages(['new_date' => 'The new date is the same as the current date.']);
        }

        $driver = Driver::findOrFail($trip->driver_id);
        $vehicleRequest = VehicleRequest::findOrFail($trip->vehicle_request_id);
        [$startDate, $endDate] = $this->tripRange($vehicleRequest, $newDate);

        $this->assertLicenseValidOn($driver, $endDate);

        $this->assertNoConflicts(
            (int) $trip->vehicle_id,
            (int) $trip->driver_id,
            $startDate,
            $endDate,
            $trip->id
        );

        return $this->shiftTripDate($trip, $newDate);
    }

    /**
     * Writes the new date on the trip and on its vehicle request. No checks here.
     * The caller must run the conflict checks first.
     *
     * The end date moves by the same number of days, so a multi-day trip
     * never ends before it starts.
     *
     * @return string the old date (YYYY-MM-DD)
     */
    public function shiftTripDate(Trip $trip, string $newDate): string
    {
        $old = Carbon::parse($trip->trip_date)->toDateString();
        $vehicleRequest = VehicleRequest::findOrFail($trip->vehicle_request_id);
        $shift = (int) Carbon::parse($old)->diffInDays(Carbon::parse($newDate), false);

        DB::transaction(function () use ($trip, $newDate, $vehicleRequest, $shift) {
            Trip::where('id', $trip->id)->update(['trip_date' => $newDate]);

            $vehicleRequest->update([
                'trip_date' => $newDate,
                'trip_end_date' => $vehicleRequest->trip_end_date->copy()->addDays($shift)->toDateString(),
            ]);
        });

        return $old;
    }

    /**
     * @param  Trip|null  $currentTrip  pass this when reassigning an existing trip
     * @param  string|null  $newDate  pass this (YYYY-MM-DD) when the trip is also moved to another date.
     *                              The checks then run against the new dates.
     * @param  bool  $allowPending  true when a pending request is approved together with its assignment
     */
    public function assertAssignable(
        VehicleRequest $vehicleRequest,
        Vehicle $vehicle,
        Driver $driver,
        ?Trip $currentTrip = null,
        ?string $newDate = null,
        bool $allowPending = false
    ): void {
        [$startDate, $endDate] = $this->tripRange($vehicleRequest, $newDate);
        $ignoreTripId = $currentTrip?->id;

        $this->assertRequestIsApproved($vehicleRequest, $allowPending);
        $this->assertNotAlreadyAllocated($vehicleRequest, $ignoreTripId);

        // Conflicts first (so the conflict modal shows up first), then readiness.
        // The vehicle and the driver are checked together, so every conflict is reported at once.
        $this->assertNoConflicts((int) $vehicle->id, (int) $driver->id, $startDate, $endDate, $ignoreTripId);

        if (! $currentTrip || (int) $vehicle->id !== (int) $currentTrip->vehicle_id) {
            $this->assertVehicleReady($vehicle);
        }

        if (! $currentTrip || (int) $driver->id !== (int) $currentTrip->driver_id) {
            $this->assertDriverReady($driver, $endDate);
        }

        // A driver who is kept on the trip still needs a valid license on the new dates.
        if ($newDate) {
            $this->assertLicenseValidOn($driver, $endDate);
        }
    }

    /**
     * Active trips that share at least one day with the given date range.
     * A trip covers its start date up to the end date of its vehicle request.
     */
    public function busyTrips(string $startDate, string $endDate, ?int $ignoreTripId = null): Builder
    {
        return Trip::query()
            ->select('trips.*')
            ->leftJoin('vehicle_requests', 'vehicle_requests.id', '=', 'trips.vehicle_request_id')
            ->whereIn('trips.trip_status', self::ACTIVE)
            ->whereDate('trips.trip_date', '<=', $endDate)
            ->whereRaw('DATE(COALESCE(vehicle_requests.trip_end_date, trips.trip_date)) >= ?', [$startDate])
            ->when($ignoreTripId, fn (Builder $q) => $q->where('trips.id', '!=', $ignoreTripId));
    }

    /**
     * Vehicles and drivers that are NOT available on the given dates, with the reason.
     * A trip in progress is reported as "On a trip (in progress)". A scheduled trip is reported as
     * "Has a scheduled trip on this date".
     *
     * @return array{vehicles: array<int,string>, drivers: array<int,string>}  id => reason
     */
    public function unavailable(string $startDate, string $endDate, ?int $ignoreTripId = null): array
    {
        $vehicles = [];
        $drivers = [];

        $mark = function (array &$list, int $id, Trip $trip) {
            $inProgress = $trip->trip_status === 'in_progress';

            // An in-progress trip is the stronger reason, so it replaces a "scheduled" one.
            if (! isset($list[$id]) || $inProgress) {
                $list[$id] = $inProgress ? 'On a trip (in progress)' : 'Has a scheduled trip on this date';
            }
        };

        foreach ($this->busyTrips($startDate, $endDate, $ignoreTripId)->get() as $trip) {
            $mark($vehicles, (int) $trip->vehicle_id, $trip);
            $mark($drivers, (int) $trip->driver_id, $trip);
        }

        return ['vehicles' => $vehicles, 'drivers' => $drivers];
    }

    protected function assertRequestIsApproved(VehicleRequest $vehicleRequest, bool $allowPending = false): void
    {
        // A pending request may pass when it is being approved together with this assignment.
        if ($allowPending && $vehicleRequest->status === 'pending') {
            return;
        }

        if ($vehicleRequest->status !== 'approved') {
            throw ValidationException::withMessages([
                'vehicle_request_id' => 'Only approved vehicle requests can be allocated a vehicle and driver.',
            ]);
        }
    }

    protected function assertNotAlreadyAllocated(VehicleRequest $vehicleRequest, ?int $ignoreTripId): void
    {
        $existing = Trip::where('vehicle_request_id', $vehicleRequest->id)->first();

        if ($existing && $existing->id !== $ignoreTripId) {
            throw ValidationException::withMessages([
                'vehicle_request_id' => 'This request already has a trip allocated (trip #' . $existing->id . ').',
            ]);
        }
    }

    protected function assertVehicleReady(Vehicle $vehicle): void
    {
        // 'in_use' is allowed: the dates block it (assertNoConflicts), not the status.
        if (! $vehicle->is_active || ! in_array($vehicle->status, ['available', 'in_use'], true)) {
            throw ValidationException::withMessages([
                'vehicle_id' => "This vehicle is currently '{$vehicle->status}' and is not ready for dispatch.",
            ]);
        }
    }

    /**
     * A driver is a record only (no login), so only availability and license are checked.
     * The license is checked against the LAST TRIP DATE, not today.
     */
    protected function assertDriverReady(Driver $driver, string $lastTripDate): void
    {
        // is_available = false only because of another trip is not a problem (assertNoConflicts handles it).
        // It blocks only when the driver was marked unavailable by hand and has no active trip.
        $hasActiveTrip = Trip::where('driver_id', $driver->id)->whereIn('trip_status', self::ACTIVE)->exists();

        if (! $driver->is_available && ! $hasActiveTrip) {
            throw ValidationException::withMessages([
                'driver_id' => 'This driver is currently marked unavailable.',
            ]);
        }

        $this->assertLicenseValidOn($driver, $lastTripDate);
    }

    protected function assertLicenseValidOn(Driver $driver, string $date): void
    {
        $expiry = $driver->license_expiry_date?->toDateString();

        if ($expiry && $expiry < $date) {
            throw ValidationException::withMessages([
                'driver_id' => "This driver's license expires before the trip date.",
            ]);
        }
    }

    /**
     * Checks the vehicle AND the driver together and reports every conflict in one 422 response.
     * A conflict is any active trip that shares at least one day with the given date range.
     *
     * The response has:
     *  - "conflicts": the full list (one entry for each conflicting trip and subject)
     *  - "conflict": the first entry, kept for older code that reads a single conflict
     */
    protected function assertNoConflicts(
        int $vehicleId,
        int $driverId,
        string $startDate,
        string $endDate,
        ?int $ignoreTripId
    ): void {
        $conflicts = [];

        foreach (['vehicle_id' => $vehicleId, 'driver_id' => $driverId] as $column => $id) {
            $trips = $this->busyTrips($startDate, $endDate, $ignoreTripId)
                ->where("trips.{$column}", $id)
                ->with(['vehicle', 'driver', 'vehicleRequest'])
                ->get();

            foreach ($trips as $trip) {
                $conflicts[] = $this->conflictDetails($column, $id, $trip);
            }
        }

        if (! $conflicts) {
            return;
        }

        $errors = [];
        foreach ($conflicts as $conflict) {
            $field = $conflict['type'] === 'vehicle' ? 'vehicle_id' : 'driver_id';
            $errors[$field][] = $conflict['message'];
        }

        // 422 with "conflicts" details for the conflict modal of the frontend.
        throw new HttpResponseException(response()->json([
            'message' => implode(' ', array_column($conflicts, 'message')),
            'errors' => $errors,
            'conflict' => $conflicts[0],
            'conflicts' => $conflicts,
        ], 422));
    }

    /**
     * Details of one conflict, for the conflict modal.
     *
     * @param  string  $column  'driver_id' or 'vehicle_id'
     * @param  Trip  $conflict  the trip that is already using the vehicle or driver
     */
    protected function conflictDetails(string $column, int $id, Trip $conflict): array
    {
        $conflict->loadMissing(['vehicle', 'driver', 'vehicleRequest']);

        $isVehicle = $column === 'vehicle_id';
        $vehicleLabel = $conflict->vehicle
            ? trim("{$conflict->vehicle->vehicle_model} ({$conflict->vehicle->plate_number})")
            : null;
        $driverLabel = $conflict->driver?->full_name;

        // The subject is the one being assigned, which is also the one already on the conflicting trip.
        $subjectName = $isVehicle ? ($vehicleLabel ?? 'Vehicle') : ($driverLabel ?: "Driver #{$id}");

        $startDate = Carbon::parse($conflict->trip_date)->toDateString();
        $endDate = Carbon::parse($conflict->vehicleRequest?->trip_end_date ?? $conflict->trip_date)->toDateString();

        $when = $endDate === $startDate
            ? Carbon::parse($startDate)->format('F j, Y')
            : Carbon::parse($startDate)->format('F j, Y') . ' to ' . Carbon::parse($endDate)->format('F j, Y');

        $message = "{$subjectName} is already scheduled on {$when} at {$conflict->departure_time}"
            . ($conflict->estimated_return_time ? " – {$conflict->estimated_return_time}" : '') . '.';

        return [
            'type' => $isVehicle ? 'vehicle' : 'driver',
            'subject' => $subjectName,
            'trip_id' => $conflict->id,
            'date' => $startDate,
            'end_date' => $endDate,
            'start' => $conflict->departure_time,
            'end' => $conflict->estimated_return_time,
            'destination' => $conflict->destination,
            'driver' => $driverLabel,
            'vehicle' => $vehicleLabel,
            'message' => $message,
        ];
    }
}