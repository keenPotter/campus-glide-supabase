<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StorePostTravelReportRequest extends FormRequest
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
            'travel_date_from' => ['required', 'date'],
            'travel_date_to' => ['nullable', 'date', 'after_or_equal:travel_date_from'],
            'places_of_travel' => ['required', 'string', 'max:500'],
            'defects_observed' => ['nullable', 'string'],
            'defects_incurred' => ['nullable', 'string'],
            'remarks' => ['nullable', 'string'],
            'drivers' => ['nullable', 'string', 'max:500'],
            'arrival_at' => ['nullable', 'date'],
        ];
    }
}