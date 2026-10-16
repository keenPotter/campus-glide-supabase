<?php

namespace App\Http\Controllers;

use App\Http\Resources\RescheduleRequestResource;
use App\Models\Allocation;
use App\Models\RescheduleRequest;
use App\Services\AllocationService;
use Illuminate\Http\Request;

/**
 * Changing the date of a trip.
 *  - Faculty can only send a request (POST allocations/{id}/reschedule-requests).
 *  - Administrators approve or disapprove a request, or reassign the date directly with a reason.
 */
class RescheduleRequestController extends Controller
{
    private const WITH = ['trip.allocation', 'requester', 'handler'];

    public function __construct(protected AllocationService $allocations)
    {
    }

    /**
     * GET /api/reschedule-requests
     * Administrators see all. Faculty see only their own. Optional: ?status=pending
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $query = RescheduleRequest::with(self::WITH)->latest();

        if ($user->hasRole('faculty')) {
            $query->whereHas('trip.vehicleRequest', fn ($q) => $q->where('requester_id', $user->id));
        }

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        return RescheduleRequestResource::collection($query->limit(100)->get());
    }

    /**
     * POST /api/allocations/{allocation}/reschedule-requests
     * Faculty only (route middleware). Faculty ask for a change; they do not move the trip.
     */
    public function store(Request $request, Allocation $allocation)
    {
        $user = $request->user();

        $allocation->loadMissing('trip.vehicleRequest');
        $trip = $allocation->trip;

        abort_unless(
            (int) $trip?->vehicleRequest?->requester_id === (int) $user->id,
            403,
            'You may only request a date change for your own trips.'
        );

        $validated = $request->validate([
            'new_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:today'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        abort_unless($trip->trip_status === 'scheduled', 422, "A {$trip->trip_status} trip can no longer be rescheduled.");

        abort_if(
            RescheduleRequest::where('trip_id', $trip->id)->where('status', 'pending')->exists(),
            422,
            'This trip already has a pending date change request.'
        );

        $oldDate = $trip->trip_date->toDateString();

        abort_if($validated['new_date'] === $oldDate, 422, 'The new date is the same as the current date.');

        $rescheduleRequest = RescheduleRequest::create([
            'trip_id' => $trip->id,
            'requested_by' => $user->id,
            'old_date' => $oldDate,
            'new_date' => $validated['new_date'],
            'reason' => $validated['reason'],
            'status' => 'pending',
        ]);

        return (new RescheduleRequestResource($rescheduleRequest->load(self::WITH)))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * POST /api/reschedule-requests/{rescheduleRequest}/approve
     * Moves the trip to the requested date. The conflict check runs first.
     * The administrator's note is optional.
     */
    public function approve(Request $request, RescheduleRequest $rescheduleRequest)
    {
        $this->assertPending($rescheduleRequest);

        $request->validate(['admin_reason' => ['nullable', 'string', 'max:500']]);

        $this->allocations->moveTrip($rescheduleRequest->trip, $rescheduleRequest->new_date->toDateString());

        $rescheduleRequest->update([
            'status' => 'approved',
            'handled_by' => $request->user()->id,
            'handled_at' => now(),
            'admin_reason' => $request->input('admin_reason'),
        ]);

        return new RescheduleRequestResource($rescheduleRequest->load(self::WITH));
    }

    /**
     * POST /api/reschedule-requests/{rescheduleRequest}/disapprove
     * The trip is not touched. The reason is required, and the faculty member can see it.
     * (This replaces the old "cancel", which deleted the request.)
     */
    public function disapprove(Request $request, RescheduleRequest $rescheduleRequest)
    {
        $this->assertPending($rescheduleRequest);

        $validated = $request->validate([
            'admin_reason' => ['required', 'string', 'max:500'],
        ]);

        $rescheduleRequest->update([
            'status' => 'disapproved',
            'handled_by' => $request->user()->id,
            'handled_at' => now(),
            'admin_reason' => $validated['admin_reason'],
        ]);

        return new RescheduleRequestResource($rescheduleRequest->load(self::WITH));
    }

    /**
     * POST /api/allocations/{allocation}/reschedule
     * Administrator reassigns the date directly. A reason is required.
     */
    public function reschedule(Request $request, Allocation $allocation)
    {
        $validated = $request->validate([
            'new_date' => ['required', 'date_format:Y-m-d', 'after_or_equal:today'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $trip = $allocation->trip;
        $oldDate = $this->allocations->moveTrip($trip, $validated['new_date']);

        // A pending faculty request is no longer needed once the date is changed directly.
        RescheduleRequest::where('trip_id', $trip->id)->where('status', 'pending')->delete();

        $rescheduleRequest = RescheduleRequest::create([
            'trip_id' => $trip->id,
            'requested_by' => $request->user()->id,
            'old_date' => $oldDate,
            'new_date' => $validated['new_date'],
            'reason' => $validated['reason'],
            'status' => 'approved',
            'handled_by' => $request->user()->id,
            'handled_at' => now(),
        ]);

        return (new RescheduleRequestResource($rescheduleRequest->load(self::WITH)))
            ->response()
            ->setStatusCode(201);
    }

    private function assertPending(RescheduleRequest $rescheduleRequest): void
    {
        abort_unless($rescheduleRequest->status === 'pending', 422, "This request is already {$rescheduleRequest->status}.");
    }
}