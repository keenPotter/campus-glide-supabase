<?php

namespace App\Http\Requests;

use App\Models\VehicleMaintenance;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreMaintenanceLogRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('administrator') ?? false;
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['required', 'integer', 'exists:vehicles,id'],
            'type' => ['required', Rule::in(VehicleMaintenance::TYPES)],
            'description' => ['nullable', 'string', 'max:500'],
            'date_performed' => ['required', 'date'],
            'cost' => ['nullable', 'numeric', 'min:0'],
            'next_due_date' => ['nullable', 'date', 'after_or_equal:date_performed'],
            'status' => ['sometimes', Rule::in(VehicleMaintenance::STATUSES)],
        ];
    }
}