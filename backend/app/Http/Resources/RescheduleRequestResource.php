<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RescheduleRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $trip = $this->trip;

        return [
            'id' => $this->id,
            'status' => $this->status,
            'old_date' => $this->old_date?->toDateString(),
            'new_date' => $this->new_date?->toDateString(),
            'reason' => $this->reason,
            'admin_reason' => $this->admin_reason,
            'requested_by' => $this->requester?->full_name,
            'handled_by' => $this->handler?->full_name,
            'handled_at' => $this->handled_at,
            'created_at' => $this->created_at,
            'allocation_id' => $trip?->allocation?->id,
            'trip' => [
                'id' => $trip?->id,
                'destination' => $trip?->destination,
                'trip_date' => $trip?->trip_date ? \Carbon\Carbon::parse($trip->trip_date)->toDateString() : null,
                'departure_time' => $trip?->departure_time,
                'estimated_return_time' => $trip?->estimated_return_time,
            ],
        ];
    }
}