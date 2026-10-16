<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostTravelReportResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'vehicle' => [
                'id' => $this->vehicle->id,
                'plate_number' => $this->vehicle->plate_number,
                'vehicle_model' => $this->vehicle->vehicle_model,
            ],
            'trip_id' => $this->trip_id,
            'travel_date_from' => $this->travel_date_from?->format('Y-m-d'),
            'travel_date_to' => $this->travel_date_to?->format('Y-m-d'),
            'places_of_travel' => $this->places_of_travel,
            'defects_observed' => $this->defects_observed,
            'defects_incurred' => $this->defects_incurred,
            'remarks' => $this->remarks,
            'drivers' => $this->drivers,
            'arrival_at' => $this->arrival_at?->toISOString(),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}