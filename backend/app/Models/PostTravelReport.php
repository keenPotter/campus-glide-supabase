<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PostTravelReport extends Model
{
    use HasFactory;

    protected $fillable = [
        'vehicle_id',
        'trip_id',
        'travel_date_from',
        'travel_date_to',
        'places_of_travel',
        'defects_observed',
        'defects_incurred',
        'remarks',
        'drivers',
        'arrival_at',
    ];

    protected function casts(): array
    {
        return [
            'travel_date_from' => 'date:Y-m-d',
            'travel_date_to' => 'date:Y-m-d',
            'arrival_at' => 'datetime',
        ];
    }

    public function vehicle()
    {
        return $this->belongsTo(Vehicle::class);
    }

    public function trip()
    {
        return $this->belongsTo(Trip::class);
    }
}