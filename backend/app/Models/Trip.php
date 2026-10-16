<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Trip extends Model
{
    protected $table = 'trips';

    protected $fillable = [
        'vehicle_request_id',
        'vehicle_id',
        'driver_id',
        'trip_date',
        'departure_time',
        'estimated_return_time',
        'destination',
        'purpose',
        'trip_status',
        'actual_departure_time',
        'actual_return_time',
        'actual_mileage',
        'notes',
    ];

    // Added: trip_date was returned as plain text, so date methods such as
    // ->toDateString() failed in the reschedule code and in TripResource.
    protected function casts(): array
    {
        return [
            'trip_date' => 'date:Y-m-d',
        ];
    }

    public function vehicleRequest()
    {
        return $this->belongsTo(VehicleRequest::class, 'vehicle_request_id');
    }

    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class, 'vehicle_id');
    }

    public function driver()
    {
        return $this->belongsTo(Driver::class, 'driver_id');
    }

    // The allocation record of this trip (used by the allocation module).
    public function allocation()
    {
        return $this->hasOne(Allocation::class);
    }
}