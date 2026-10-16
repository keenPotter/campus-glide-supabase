<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;

class Driver extends Model
{
    protected $fillable = [
        'first_name',
        'last_name',
        'license_number',
        'license_expiry_date',
        'contact_number',
        'address',
        'assigned_vehicle_id',
        'is_available',
    ];

    protected function casts(): array
    {
        return [
            'license_expiry_date' => 'date:Y-m-d',
        ];
    }

    // "First Last". Used by the allocation module instead of rebuilding the name in many places.
    protected function fullName(): Attribute
    {
        return Attribute::make(
            get: fn () => trim("{$this->first_name} {$this->last_name}"),
        );
    }
}