<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VehicleRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'destination' => $this->destination,
            'purpose' => $this->purpose,
            'trip_date' => $this->trip_date?->format('Y-m-d'),
            'trip_end_date' => $this->trip_end_date?->format('Y-m-d'),
            'travel_days' => $this->travel_days,
            'trip_type' => $this->trip_type,
            'departure_time' => $this->departure_time,
            'return_time' => $this->estimated_return_time,
            'passengers' => $this->passengers,
            'number_of_passengers' => $this->number_of_passengers,
            'disapproval_reason' => $this->disapproval_reason,
            // Reason the requester gave when editing the request after it was approved.
            'edit_reason' => $this->edit_reason,
            'approved_by' => $this->approved_by,
            'approved_date' => $this->approved_date?->toIso8601String(),
            'requested_by' => [
                'id' => $this->requester->id,
                'first_name' => $this->requester->first_name,
                'last_name' => $this->requester->last_name,
            ],
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}