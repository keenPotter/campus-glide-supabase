<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VehicleMaintenance extends Model
{
    use HasFactory;

    protected $table = 'vehicle_maintenance';

    public const TYPES = [
        'oil_change',
        'repair',
        'refueling',
        'inspection',
        'tire_service',
        'other',
    ];

    // Moved here from the controller so the Form Requests can share it.
    public const STATUSES = [
        'scheduled',
        'in_progress',
        'completed',
        'cancelled',
    ];

    // Column names match the database exactly — no renaming.
    protected $fillable = [
        'vehicle_id',
        'maintenance_type',
        'description',
        'maintenance_date',
        'completion_date',
        'next_due_date',
        'cost',
        'performed_by',
        'status',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'maintenance_date' => 'date:Y-m-d',
            'completion_date' => 'date:Y-m-d',
            'next_due_date' => 'date:Y-m-d',
            'cost' => 'decimal:2',
        ];
    }

    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class);
    }
}