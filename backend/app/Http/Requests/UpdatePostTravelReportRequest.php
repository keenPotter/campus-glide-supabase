<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdatePostTravelReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('administrator') ?? false;
    }

    // If only travel_date_to is sent, compare it with the saved travel_date_from.
    // Without this, the "after_or_equal" rule has nothing to compare against and fails.
    protected function prepareForValidation(): void
    {
        if ($this->has('travel_date_to') && ! $this->has('travel_date_from')) {
            $this->merge([
                'travel_date_from' => $this->route('postTravelReport')->travel_date_from->toDateString(),
            ]);
        }
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['sometimes', 'integer', 'exists:vehicles,id'],
            'trip_id' => ['nullable', 'integer', 'exists:trips,id'],
            'travel_date_from' => ['sometimes', 'date'],
            'travel_date_to' => ['nullable', 'date', 'after_or_equal:travel_date_from'],
            'places_of_travel' => ['sometimes', 'string', 'max:500'],
            'defects_observed' => ['nullable', 'string'],
            'defects_incurred' => ['nullable', 'string'],
            'remarks' => ['nullable', 'string'],
            'drivers' => ['nullable', 'string', 'max:500'],
            'arrival_at' => ['nullable', 'date'],
        ];
    }
}