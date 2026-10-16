<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreAllocationRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Only administrators can assign a vehicle and driver.
        return $this->user()?->hasRole('administrator') ?? false;
    }

    public function rules(): array
    {
        return [
            'vehicle_request_id' => ['required', 'integer', 'exists:vehicle_requests,id'],
            'vehicle_id' => ['required', 'integer', 'exists:vehicles,id'],
            // drivers.id, not users.id
            'driver_id' => ['required', 'integer', 'exists:drivers,id'],
            'notes' => ['nullable', 'string', 'max:500'],
            // Sent when the administrator approves a pending request and assigns it in one step.
            'approve_request' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'vehicle_request_id.exists' => 'Vehicle request not found.',
            'vehicle_id.exists' => 'Vehicle not found.',
            'driver_id.exists' => 'Driver not found.',
        ];
    }
}