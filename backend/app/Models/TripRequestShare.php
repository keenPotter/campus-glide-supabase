<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TripRequestShare extends Model
{
    protected $fillable = [
        'allocation_id',
        'sender_id',
        'recipient_id',
    ];

    public function allocation()
    {
        return $this->belongsTo(Allocation::class);
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function recipient()
    {
        return $this->belongsTo(User::class, 'recipient_id');
    }
}
