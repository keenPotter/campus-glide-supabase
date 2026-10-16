<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateVehicleRequestStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        $vehicleRequest = $this->route('vehicleRequest');

        return $this->user()?->hasRole('administrator')
            && $vehicleRequest
            && $vehicleRequest->status === 'pending';
    }

    public function rules(): array
    {
        return [
            'status' => ['required', 'in:approved,disapproved'],
            'remarks' => ['nullable', 'required_if:status,disapproved', 'string', 'max:500'],
        ];
    }

    public function messages(): array
    {
        return [
            'remarks.required_if' => 'Please provide a reason for disapproval.',
        ];
    }
}