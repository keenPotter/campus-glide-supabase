<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class EditVehicleRequestRequest extends FormRequest
{
    public function authorize(): bool
    {
        $vehicleRequest = $this->route('vehicleRequest');

        return $vehicleRequest
            && (int) $vehicleRequest->requester_id === (int) $this->user()->id
            && in_array($vehicleRequest->status, ['pending', 'approved'], true);
    }

    public function rules(): array
    {
        // A reason is required only when the request is already approved.
        $isApproved = $this->route('vehicleRequest')?->status === 'approved';

        return [
            'trip_date' => ['required', 'date'],
            'trip_end_date' => ['required', 'date', 'after_or_equal:trip_date'],
            'trip_type' => ['required', 'in:inclusive,exclusive'],
            'departure_time' => ['required', 'date_format:H:i'],
            'destination' => ['required', 'string', 'max:255'],
            'purpose' => ['required', 'string', 'max:255'],
            'estimated_return_time' => ['required', 'date_format:H:i', 'after:departure_time'],
            'passengers' => ['required', 'string', 'max:255'],
            'number_of_passengers' => ['required', 'integer', 'min:1'],
            'edit_reason' => [$isApproved ? 'required' : 'nullable', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'edit_reason.required' => 'Please give a reason for editing this approved request.',
        ];
    }
}