<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VehicleRequest extends Model
{
    use HasFactory;

    protected $table = 'vehicle_requests';

    protected $fillable = [
        'requester_id',
        'request_date',
        'trip_date',
        'trip_end_date',
        'trip_type',
        'departure_time',
        'destination',
        'purpose',
        'estimated_return_time',
        'passengers',
        'number_of_passengers',
        'status',
        'disapproval_reason',
        'edit_reason',
        'approved_by',
        'approved_date',
    ];

    protected function casts(): array
    {
        return [
            'trip_date' => 'date',
            'trip_end_date' => 'date',
            'request_date' => 'datetime',
            'approved_date' => 'datetime',
        ];
    }

    // Number of travel days, counting both the first and the last day.
    // Cast to a whole number; it was returned as a decimal (for example 3.0).
    protected function travelDays(): Attribute
    {
        return Attribute::make(
            get: fn () => $this->trip_date && $this->trip_end_date
                ? (int) $this->trip_date->diffInDays($this->trip_end_date) + 1
                : null,
        );
    }

    public function trip()
    {
        return $this->hasOne(Trip::class, 'vehicle_request_id');
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function approver()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }
}