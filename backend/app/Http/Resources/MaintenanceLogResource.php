<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Uses the API field names (`type`, `date_performed`),
 * which map to the database columns `maintenance_type` and `maintenance_date`.
 */
class MaintenanceLogResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'vehicle' => [
                'id' => $this->vehicle->id,
                'plate_number' => $this->vehicle->plate_number,
                'model' => $this->vehicle->vehicle_model,
                'mileage' => $this->vehicle->mileage,
            ],
            'type' => $this->maintenance_type,
            'description' => $this->description,
            'status' => $this->status,
            'date_performed' => $this->maintenance_date?->format('Y-m-d'),
            'cost' => $this->cost !== null ? (float) $this->cost : null,
            'next_due_date' => $this->next_due_date?->format('Y-m-d'),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}