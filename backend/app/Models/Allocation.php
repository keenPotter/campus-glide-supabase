<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Audit record of who assigned which vehicle and driver to a trip, and when.
 * It points to an existing `trips` row. The live status is kept in Trip::trip_status.
 */
class Allocation extends Model
{
    use HasFactory;

    protected $fillable = [
        'trip_id',
        'vehicle_id',
        'driver_id',
        'allocated_by',
        'allocation_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'allocation_date' => 'datetime',
        ];
    }

    public function trip()
    {
        return $this->belongsTo(Trip::class);
    }

    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class);
    }

    // driver_id points to drivers.id (not users.id)
    public function driver()
    {
        return $this->belongsTo(Driver::class);
    }

    public function allocatedBy()
    {
        return $this->belongsTo(User::class, 'allocated_by');
    }
}