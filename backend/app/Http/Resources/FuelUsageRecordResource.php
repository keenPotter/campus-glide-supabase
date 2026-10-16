<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class FuelUsageRecordResource extends JsonResource
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
            'record_date' => $this->record_date?->format('Y-m-d'),
            'balance_in_tank' => $this->number($this->balance_in_tank),
            'issuance_from_stock' => $this->number($this->issuance_from_stock),
            'fuel_purchased' => $this->number($this->fuel_purchased),
            'fuel_used' => $this->number($this->fuel_used),
            'end_trip_balance' => $this->number($this->end_trip_balance),
            'riv_no' => $this->riv_no,
            'riv_date' => $this->riv_date?->format('Y-m-d'),
            'or_no' => $this->or_no,
            'or_date' => $this->or_date?->format('Y-m-d'),
            'lubricating_oil' => $this->number($this->lubricating_oil),
            'diesel_water' => $this->number($this->diesel_water),
            'gear_oil' => $this->number($this->gear_oil),
            'brake_fluid' => $this->number($this->brake_fluid),
            'flushing_oil' => $this->number($this->flushing_oil),
            'grease' => $this->number($this->grease),
            'drivers' => $this->drivers,
            'created_at' => $this->created_at?->toISOString(),
        ];
    }

    // The database returns amounts as text (for example "12.50"). The API returns real numbers.
    private function number($value): ?float
    {
        return $value === null ? null : (float) $value;
    }
}