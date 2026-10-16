<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PreventiveMaintenanceChecklist extends Model
{
    use HasFactory;

    public const RATINGS = ['excellent', 'good', 'poor'];

    // Moved here from the controller so the Form Requests and the Resource can share it.
    public const RATING_FIELDS = [
        'belts_condition', 'hoses_condition', 'engine_condition',
        'air_conditioning_condition', 'wipers_condition',
        'headlights_condition', 'driving_lights_condition',
        'brake_lights_condition', 'hazard_lights_condition',
        'door_locks_condition', 'windows_windshield_condition',
        'radio_condition', 'tires_condition', 'liquid_levels_condition',
        'other_parts_condition',
    ];

    protected $fillable = [
        'vehicle_id', 'pmuv_no', 'inspection_date', 'inspector_mechanic',
        'current_mileage', 'last_oil_change', 'last_air_filter_change',
        'last_cabin_filter_change', 'last_oil_filter_change', 'last_engine_tune_up',
        'belts_condition', 'hoses_condition', 'engine_condition',
        'air_conditioning_condition', 'wipers_condition',
        'headlights_condition', 'driving_lights_condition',
        'brake_lights_condition', 'hazard_lights_condition',
        'door_locks_condition', 'windows_windshield_condition',
        'radio_condition', 'tires_condition', 'liquid_levels_condition',
        'other_parts_condition', 'other_parts', 'remarks',
        'supervisor_recommendation',
    ];

    protected function casts(): array
    {
        return [
            'inspection_date' => 'date:Y-m-d',
            'last_oil_change' => 'date:Y-m-d',
            'last_air_filter_change' => 'date:Y-m-d',
            'last_cabin_filter_change' => 'date:Y-m-d',
            'last_oil_filter_change' => 'date:Y-m-d',
            'last_engine_tune_up' => 'date:Y-m-d',
            'current_mileage' => 'integer',
        ];
    }

    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class);
    }
}