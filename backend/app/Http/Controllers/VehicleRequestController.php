<?php

namespace App\Http\Controllers;

use App\Http\Requests\EditVehicleRequestRequest;
use App\Http\Requests\StoreVehicleRequestRequest;
use App\Http\Requests\UpdateVehicleRequestStatusRequest;
use App\Http\Resources\VehicleRequestResource;
use App\Models\Driver;
use App\Models\Trip;
use App\Models\Vehicle;
use App\Models\VehicleRequest;
use App\Services\AllocationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class VehicleRequestController extends Controller
{
    /**
     * GET /api/vehicle-requests
     * Administrators see all. Faculty see only their own.
     * Query params: ?status=pending, ?trip_type=inclusive
     *
     * Order: pending requests first, with the soonest travel date on top.
     * All other requests follow, newest first.
     * The sorting is done here (not in the frontend) so it covers every page.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $query = VehicleRequest::with('requester')
            ->orderByRaw("CASE WHEN status = 'pending' THEN 0 ELSE 1 END")
            ->orderByRaw("CASE WHEN status = 'pending' THEN trip_date END ASC")
            ->orderByRaw("CASE WHEN status = 'pending' THEN departure_time END ASC")
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($user->hasRole('faculty')) {
            $query->where('requester_id', $user->id);
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        // The frontend sends trip_type, so the backend must filter by it too.
        if ($tripType = $request->query('trip_type')) {
            $query->where('trip_type', $tripType);
        }

        return VehicleRequestResource::collection($query->paginate(20));
    }

    /**
     * GET /api/vehicle-requests/approved
     * Approved requests that do not have a trip yet. Administrators only (route middleware).
     */
    public function approved()
    {
        $requests = VehicleRequest::with('requester')
            ->where('status', 'approved')
            ->whereDoesntHave('trip')
            ->orderBy('trip_date')
            ->orderBy('departure_time')
            ->get();

        return VehicleRequestResource::collection($requests);
    }

    public function store(StoreVehicleRequestRequest $request)
    {
        $vehicleRequest = VehicleRequest::create([
            'requester_id' => $request->user()->id,
            'request_date' => now(),
            'destination' => $request->destination,
            'purpose' => $request->purpose,
            'trip_date' => $request->trip_date,
            'trip_end_date' => $request->trip_end_date,
            'trip_type' => $request->trip_type,
            'departure_time' => $request->departure_time,
            'estimated_return_time' => $request->estimated_return_time,
            'passengers' => $request->passengers,
            'number_of_passengers' => $request->number_of_passengers,
            'status' => 'pending',
        ]);

        return new VehicleRequestResource($vehicleRequest->load('requester'));
    }

    public function show(Request $request, VehicleRequest $vehicleRequest)
    {
        $user = $request->user();

        if ($user->hasRole('faculty') && $vehicleRequest->requester_id !== $user->id) {
            abort(403, 'You are not authorized to view this request.');
        }

        return new VehicleRequestResource($vehicleRequest->load('requester'));
    }

    public function updateStatus(UpdateVehicleRequestStatusRequest $request, VehicleRequest $vehicleRequest)
    {
        $isApproved = $request->status === 'approved';

        $vehicleRequest->update([
            'status' => $request->status,
            'disapproval_reason' => $isApproved ? null : $request->remarks,
            'approved_by' => $request->user()->id,
            'approved_date' => $isApproved ? now() : null,
        ]);

        return new VehicleRequestResource($vehicleRequest->fresh('requester'));
    }

    /**
     * PUT /api/vehicle-requests/{id}/edit
     * Faculty edit their own request.
     * Editing an approved request (a reason is required) makes it a new pending request:
     * its trip is deleted, the vehicle and driver are freed, and the administrator must approve it again.
     */
    public function edit(EditVehicleRequestRequest $request, VehicleRequest $vehicleRequest)
    {
        $validated = $request->validated();
        $wasApproved = $vehicleRequest->status === 'approved';
        $trip = $vehicleRequest->trip;

        // A trip that already started or finished cannot be undone by editing the request.
        abort_if(
            $trip && $trip->trip_status !== 'scheduled',
            422,
            "This request can no longer be edited because its trip is already {$trip?->trip_status}."
        );

        if ($wasApproved) {
            $validated = [
                ...$validated,
                'status' => 'pending',
                'approved_by' => null,
                'approved_date' => null,
            ];
        }

        DB::transaction(function () use ($vehicleRequest, $trip, $validated) {
            if ($trip) {
                $this->releaseTrip($trip);
            }

            $vehicleRequest->update($validated);
        });

        return response()->json([
            'message' => 'Vehicle request updated successfully.',
            'data' => new VehicleRequestResource($vehicleRequest->fresh(['requester', 'approver'])),
        ]);
    }

    /**
     * Deletes a trip and frees its vehicle and driver, unless another active trip still uses them.
     * The allocation record, date change requests and shared copies are deleted with the trip.
     */
    private function releaseTrip(Trip $trip): void
    {
        $vehicleId = $trip->vehicle_id;
        $driverId = $trip->driver_id;

        $trip->delete();

        $stillUsed = fn (string $column, int $id) => Trip::where($column, $id)
            ->whereIn('trip_status', AllocationService::ACTIVE)
            ->exists();

        if (! $stillUsed('vehicle_id', $vehicleId)) {
            // Only an "in use" vehicle is reset, so a vehicle under maintenance keeps its status.
            Vehicle::where('id', $vehicleId)->where('status', 'in_use')->update(['status' => 'available']);
        }

        if (! $stillUsed('driver_id', $driverId)) {
            Driver::where('id', $driverId)->update(['is_available' => true, 'assigned_vehicle_id' => null]);
        }
    }
}