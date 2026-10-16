<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreFuelUsageRecordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('administrator') ?? false;
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['required', 'integer', 'exists:vehicles,id'],
            'trip_id' => ['nullable', 'integer', 'exists:trips,id'],
            'record_date' => ['required', 'date'],
            'balance_in_tank' => ['required', 'numeric', 'min:0'],
            'issuance_from_stock' => ['required', 'numeric', 'min:0'],
            'fuel_purchased' => ['required', 'numeric', 'min:0'],
            'fuel_used' => ['required', 'numeric', 'min:0'],
            'end_trip_balance' => ['required', 'numeric', 'min:0'],
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