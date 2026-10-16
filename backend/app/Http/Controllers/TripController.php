<?php

namespace App\Http\Controllers;

use App\Http\Resources\TripResource;
use App\Models\Trip;
use App\Services\AllocationService;
use Illuminate\Http\Request;

/**
 * Read-only access to trips.
 * Trips are created and changed only through the allocation module
 * (AllocationController), so the vehicle, driver and allocation record stay in sync.
 */
class TripController extends Controller
{
    private const WITH = ['driver', 'vehicle', 'vehicleRequest.requester'];

    public function __construct(protected AllocationService $allocations)
    {
    }

    /**
     * GET /api/trips
     * All trips. Administrators only (route middleware).
     * Trips that already passed their return time are marked completed first.
     */
    public function index()
    {
        $this->allocations->completeFinishedTrips();

        $trips = Trip::with(self::WITH)
            ->orderBy('trip_date')
            ->orderBy('departure_time')
            ->get();

        return TripResource::collection($trips);
    }

    /**
     * GET /api/my-trips
     * Trips of the logged-in faculty member only.
     * Filtered through the vehicle request's requester_id, so faculty
     * cannot see the trips of other users.
     */
    public function myTrips(Request $request)
    {
        $this->allocations->completeFinishedTrips();

        $trips = Trip::with(self::WITH)
            ->whereHas('vehicleRequest', fn ($query) => $query->where('requester_id', $request->user()->id))
            ->orderBy('trip_date')
            ->orderBy('departure_time')
            ->get();

        return TripResource::collection($trips);
    }

    /**
     * GET /api/trips/{trip}
     */
    public function show(Trip $trip)
    {
        return new TripResource($trip->load(self::WITH));
    }
}