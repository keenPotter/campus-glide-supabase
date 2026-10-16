<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Vehicle extends Model
{
    use HasFactory;

    public const STATUSES = [
        'available',
        'in_use',
        'maintenance',
        'retired',
    ];

    protected $fillable = [
        'plate_number',
        'vehicle_model',
        'vehicle_type',
        'color',
        'manufacture_year',
        'capacity',
        'mileage',
        'status',
        'last_maintenance_date',
        'next_maintenance_date',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'last_maintenance_date' => 'date:Y-m-d',
            'next_maintenance_date' => 'date:Y-m-d',
            'is_active' => 'boolean',
        ];
    }

    public function maintenanceLogs()
    {
        return $this->hasMany(VehicleMaintenance::class);
    }

    public function postTravelReports()
    {
        return $this->hasMany(PostTravelReport::class);
    }

    public function fuelUsageRecords()
    {
        return $this->hasMany(FuelUsageRecord::class);
    }

    public function preventiveMaintenanceChecklists()
    {
        return $this->hasMany(PreventiveMaintenanceChecklist::class);
    }

    /**
     * Most recent maintenance entry for this vehicle, by maintenance_date.
     */
    public function latestMaintenanceLog()
    {
        return $this->hasOne(VehicleMaintenance::class)
            ->latestOfMany('maintenance_date');
    }
}