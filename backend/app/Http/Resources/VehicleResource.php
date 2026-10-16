<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VehicleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'plate_number' => $this->plate_number,
            'vehicle_model' => $this->vehicle_model,
            'vehicle_type' => $this->vehicle_type,
            'color' => $this->color,
            'manufacture_year' => $this->manufacture_year,
            'capacity' => $this->capacity,
            'mileage' => $this->mileage,
            'status' => $this->status,
            'last_maintenance_date' => $this->last_maintenance_date?->format('Y-m-d'),
            'next_maintenance_date' => $this->next_maintenance_date?->format('Y-m-d'),
            'is_active' => $this->is_active,
        ];
    }
}