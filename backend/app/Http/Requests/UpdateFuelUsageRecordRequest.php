<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateFuelUsageRecordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('administrator') ?? false;
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['sometimes', 'integer', 'exists:vehicles,id'],
            'trip_id' => ['nullable', 'integer', 'exists:trips,id'],
            'record_date' => ['sometimes', 'date'],
            'balance_in_tank' => ['sometimes', 'numeric', 'min:0'],
            'issuance_from_stock' => ['sometimes', 'numeric', 'min:0'],
            'fuel_purchased' => ['sometimes', 'numeric', 'min:0'],
            'fuel_used' => ['sometimes', 'numeric', 'min:0'],
            'end_trip_balance' => ['sometimes', 'numeric', 'min:0'],
            'riv_no' => ['nullable', 'string', 'max:100'],
            'riv_date' => ['nullable', 'date'],
            'or_no' => ['nullable', 'string', 'max:100'],
            'or_date' => ['nullable', 'date'],
            'lubricating_oil' => ['nullable', 'numeric', 'min:0'],
            'diesel_water' => ['nullable', 'numeric', 'min:0'],
            'gear_oil' => ['nullable', 'numeric', 'min:0'],
            'brake_fluid' => ['nullable', 'numeric', 'min:0'],
            'flushing_oil' => ['nullable', 'numeric', 'min:0'],
            'grease' => ['nullable', 'numeric', 'min:0'],
            'drivers' => ['nullable', 'string', 'max:500'],
        ];
    }
}