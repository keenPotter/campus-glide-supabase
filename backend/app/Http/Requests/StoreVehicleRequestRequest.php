<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreVehicleRequestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('faculty') ?? false;
    }

    public function rules(): array
    {
        return [
            'destination' => ['required', 'string', 'max:255'],
            'purpose' => ['required', 'string', 'max:255'],
            'trip_date' => ['required', 'date', 'after_or_equal:today'],
            'trip_end_date' => ['required', 'date', 'after_or_equal:trip_date'],
            'trip_type' => ['required', 'in:inclusive,exclusive'],
            'departure_time' => ['required', 'date_format:H:i'],
            'estimated_return_time' => ['required', 'date_format:H:i', 'after:departure_time'],
            'passengers' => ['required', 'string', 'max:255'],
            // Now required: the number_of_passengers column does not accept empty values.
            'number_of_passengers' => ['required', 'integer', 'min:1'],
        ];
    }
}