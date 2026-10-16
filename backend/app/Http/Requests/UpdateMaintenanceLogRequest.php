<?php

namespace App\Http\Requests;

use App\Models\VehicleMaintenance;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateMaintenanceLogRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('administrator') ?? false;
    }

    // If only next_due_date is sent, compare it with the saved maintenance date.
    // Without this, the "after_or_equal" rule has nothing to compare against and fails.
    protected function prepareForValidation(): void
    {
        if ($this->filled('next_due_date') && ! $this->has('date_performed')) {
            $this->merge([
                'date_performed' => $this->route('maintenanceLog')->maintenance_date->toDateString(),
            ]);
        }
    }

    public function rules(): array
    {
        return [
            'vehicle_id' => ['sometimes', 'integer', 'exists:vehicles,id'],
            'type' => ['sometimes', Rule::in(VehicleMaintenance::TYPES)],
            'description' => ['nullable', 'string', 'max:500'],
            'date_performed' => ['sometimes', 'date'],
            'cost' => ['nullable', 'numeric', 'min:0'],
            'next_due_date' => ['nullable', 'date', 'after_or_equal:date_performed'],
            'status' => ['sometimes', Rule::in(VehicleMaintenance::STATUSES)],
        ];
    }
}