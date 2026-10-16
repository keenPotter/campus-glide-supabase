<?php

namespace App\Http\Controllers;

use App\Http\Resources\TripRequestShareResource;
use App\Models\Allocation;
use App\Models\TripRequestShare;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Sending a printed trip request to another administrator.
 * Administrators only (route middleware).
 */
class TripRequestShareController extends Controller
{
    private const WITH = [
        'allocation.trip.vehicleRequest.requester',
        'allocation.vehicle',
        'allocation.driver',
        'allocation.allocatedBy',
        'sender',
        'recipient',
    ];

    /**
     * GET /api/admins
     * Other active administrators who can receive a trip request.
     */
    public function admins(Request $request): JsonResponse
    {
        $admins = User::where('role', User::ROLE_ADMINISTRATOR)
            ->where('is_active', true)
            ->where('id', '!=', $request->user()->id)
            ->orderBy('email')
            ->get()
            ->map(fn (User $user) => [
                'id' => $user->id,
                'name' => $user->full_name,
                'email' => $user->email,
            ])
            ->values();

        return response()->json(['data' => $admins]);
    }

    /**
     * GET /api/trip-request-shares
     * Trip requests sent to the logged-in administrator.
     */
    public function index(Request $request)
    {
        $shares = TripRequestShare::with(self::WITH)
            ->where('recipient_id', $request->user()->id)
            ->latest()
            ->limit(100)
            ->get();

        return TripRequestShareResource::collection($shares);
    }

    /**
     * POST /api/trip-request-shares
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'allocation_id' => ['required', 'integer', 'exists:allocations,id'],
            'recipient_id' => [
                'required',
                'integer',
                Rule::exists('users', 'id')->where('role', User::ROLE_ADMINISTRATOR),
            ],
        ]);

        abort_if((int) $validated['recipient_id'] === (int) $request->user()->id, 422, 'Choose another admin.');

        $allocation = Allocation::findOrFail($validated['allocation_id']);

        $share = TripRequestShare::create([
            'allocation_id' => $allocation->id,
            'sender_id' => $request->user()->id,
            'recipient_id' => $validated['recipient_id'],
        ]);

        return (new TripRequestShareResource($share->load(self::WITH)))
            ->response()
            ->setStatusCode(201);
    }
}