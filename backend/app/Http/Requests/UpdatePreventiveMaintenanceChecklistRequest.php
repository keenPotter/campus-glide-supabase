<?php

namespace App\Http\Requests;

use App\Models\PreventiveMaintenanceChecklist;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePreventiveMaintenanceChecklistRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole('administrator') ?? false;
    }

    public function rules(): array
    {
        $rules = [
            'vehicle_id' => ['sometimes', 'integer', 'exists:vehicles,id'],
            'pmuv_no' => ['nullable', 'string', 'max:100'],
            'inspection_date' => ['sometimes', 'date'],
            'inspector_mechanic' => ['nullable', 'string', 'max:255'],
            'current_mileage' => ['nullable', 'integer', 'min:0'],
            'last_oil_change' => ['nullable', 'date'],
            'last_air_filter_change' => ['nullable', 'date'],
            'last_cabin_filter_change' => ['nullable', 'date'],
            'last_oil_filter_change' => ['nullable', 'date'],
            'last_engine_tune_up' => ['nullable', 'date'],
            'other_parts' => ['nullable', 'string'],
            'remarks' => ['nullable', 'string'],
            'supervisor_recommendation' => ['nullable', 'string'],
        ];

        foreach (PreventiveMaintenanceChecklist::RATING_FIELDS as $field) {
            $rules[$field] = ['nullable', Rule::in(PreventiveMaintenanceChecklist::RATINGS)];
        }

        return $rules;
    }
}