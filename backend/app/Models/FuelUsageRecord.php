<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FuelUsageRecord extends Model
{
    use HasFactory;

    protected $fillable = [
        'vehicle_id', 'trip_id', 'record_date',
        'balance_in_tank', 'issuance_from_stock', 'fuel_purchased',
        'fuel_used', 'end_trip_balance',
        'riv_no', 'riv_date', 'or_no', 'or_date',
        'lubricating_oil', 'diesel_water', 'gear_oil',
        'brake_fluid', 'flushing_oil', 'grease', 'drivers',
    ];

    protected function casts(): array
    {
        return [
            'record_date' => 'date:Y-m-d',
            'riv_date' => 'date:Y-m-d',
            'or_date' => 'date:Y-m-d',
            'balance_in_tank' => 'decimal:2',
            'issuance_from_stock' => 'decimal:2',
            'fuel_purchased' => 'decimal:2',
            'fuel_used' => 'decimal:2',
            'end_trip_balance' => 'decimal:2',
            'lubricating_oil' => 'decimal:2',
            'diesel_water' => 'decimal:2',
            'gear_oil' => 'decimal:2',
            'brake_fluid' => 'decimal:2',
            'flushing_oil' => 'decimal:2',
            'grease' => 'decimal:2',
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