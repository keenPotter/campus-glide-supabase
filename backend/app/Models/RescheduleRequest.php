<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A request to change the date of a trip (from faculty),
 * or the record of a direct change by an administrator (status 'approved' right away).
 */
class RescheduleRequest extends Model
{
    protected $fillable = [
        'trip_id', 'requested_by', 'old_date', 'new_date', 'reason',
        'status', 'handled_by', 'admin_reason', 'handled_at',
    ];

    protected function casts(): array
    {
        return [
            'old_date' => 'date:Y-m-d',
            'new_date' => 'date:Y-m-d',
            'handled_at' => 'datetime',
        ];
    }

    public function trip()
    {
        return $this->belongsTo(Trip::class);
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function handler()
    {
        return $this->belongsTo(User::class, 'handled_by');
    }
}