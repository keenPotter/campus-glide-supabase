<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAllocationRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Only administrators can reassign a vehicle, driver or date.
        return $this->user()?->hasRole('administrator') ?? false;
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['sometimes', 'required', 'integer', 'exists:vehicles,id'],
            // drivers.id, not users.id
            'driver_id' => ['sometimes', 'required', 'integer', 'exists:drivers,id'],
            // Matches the trips.trip_status enum (the allocations table has no status column).
            'status' => ['sometimes', 'required', 'in:scheduled,in_progress,completed'],
            'notes' => ['nullable', 'string', 'max:500'],
            // Sent only when the date is changed. A reason is required together with it.
            'new_date' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after_or_equal:today'],
            'reason' => ['required_with:new_date', 'nullable', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'vehicle_id.exists' => 'Vehicle not found.',
            'driver_id.exists' => 'Driver not found.',
            'reason.required_with' => 'Please give a reason for changing the date.',
        ];
    }
}