<?php

namespace App\Http\Resources;

use App\Models\PreventiveMaintenanceChecklist;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PreventiveMaintenanceChecklistResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // All condition ratings (belts, hoses, engine, ...) are read from one shared list.
        $ratings = [];
        foreach (PreventiveMaintenanceChecklist::RATING_FIELDS as $field) {
            $ratings[$field] = $this->{$field};
        }

        return [
            'id' => $this->id,
            'vehicle' => [
                'id' => $this->vehicle->id,
                'plate_number' => $this->vehicle->plate_number,
                'vehicle_model' => $this->vehicle->vehicle_model,
            ],
            'pmuv_no' => $this->pmuv_no,
            'inspection_date' => $this->inspection_date?->format('Y-m-d'),
            'inspector_mechanic' => $this->inspector_mechanic,
            'current_mileage' => $this->current_mileage,
            'last_oil_change' => $this->last_oil_change?->format('Y-m-d'),
            'last_air_filter_change' => $this->last_air_filter_change?->format('Y-m-d'),
            'last_cabin_filter_change' => $this->last_cabin_filter_change?->format('Y-m-d'),
            'last_oil_filter_change' => $this->last_oil_filter_change?->format('Y-m-d'),
            'last_engine_tune_up' => $this->last_engine_tune_up?->format('Y-m-d'),
            ...$ratings,
            'other_parts' => $this->other_parts,
            'remarks' => $this->remarks,
            'supervisor_recommendation' => $this->supervisor_recommendation,
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}