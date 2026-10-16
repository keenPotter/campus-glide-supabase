<?php

namespace App\Http\Controllers;

use App\Models\Allocation;
use Carbon\Carbon;

/**
 * The one place that builds the printable "Request for Use of Vehicle" form.
 * The allocation page uses it (GET /api/allocations/{allocation}/print).
 * Administrators only (route middleware).
 */
class AllocationPrintController extends Controller
{
    // Officers whose names are printed on the form.
    // Change the names here if the officers change. This is the only place they are written.
    private const CHIEF_MOTORPOOL = 'TONY O. BASATAN';
    private const UNIT_HEAD_GSU = 'JAYSON R. PIMENTEL';

    public function show(Allocation $allocation)
    {
        $allocation->load(['trip.vehicleRequest.requester', 'vehicle', 'driver']);
        $vehicleRequest = $allocation->trip?->vehicleRequest;

        // Only an approved request with a vehicle and driver assigned can be printed.
        if (
            ! $vehicleRequest
            || $vehicleRequest->status !== 'approved'
            || ! $allocation->vehicle
            || ! $allocation->driver
        ) {
            abort(response()->json([
                'message' => 'Only approved requests with a vehicle and driver assigned can be printed.',
            ], 422));
        }

        $requester = $vehicleRequest->requester;

        $start = $vehicleRequest->trip_date;
        $end = $vehicleRequest->trip_end_date ?? $start;

        $travelDate = $end->isSameDay($start)
            ? $start->format('F j, Y')
            : $start->format('F j, Y') . ' to ' . $end->format('F j, Y');

        $requestedAt = $vehicleRequest->request_date ?? $vehicleRequest->created_at;

        return response()->view('print.vehicle-request', [
            'logo' => $this->logo(),
            'requestNo' => $vehicleRequest->id,
            'official' => $requester ? strtoupper($requester->full_name) : '',
            'position' => $requester?->position ?? '',
            'destination' => $vehicleRequest->destination,
            'purpose' => $vehicleRequest->purpose,
            'passengers' => $vehicleRequest->passengers,
            'travelDate' => $travelDate,
            'days' => $vehicleRequest->travel_days ?? '',
            'tripType' => $vehicleRequest->trip_type,
            'departure' => $this->time($vehicleRequest->departure_time),
            'dateRequested' => $requestedAt ? $requestedAt->format('F j, Y') : '',
            'timeRequested' => $requestedAt ? $requestedAt->format('g:i A') : '',
            // Filled in by the allocation.
            'plateNumber' => $allocation->vehicle->plate_number,
            'driverName' => $allocation->driver->full_name,
            'chiefMotorpool' => self::CHIEF_MOTORPOOL,
            'unitHeadGsu' => self::UNIT_HEAD_GSU,
        ]);
    }

    // Turns "06:00:00" into "6:00 AM".
    private function time(?string $value): string
    {
        if (! $value) {
            return '';
        }

        try {
            return Carbon::parse($value)->format('g:i A');
        } catch (\Throwable $e) {
            return (string) $value;
        }
    }

    // The logo is embedded in the page so it always prints.
    private function logo(): ?string
    {
        $path = public_path('images/nvsu-logo.png');

        if (! file_exists($path)) {
            return null;
        }

        return 'data:image/png;base64,' . base64_encode(file_get_contents($path));
    }
}