<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TripRequestShareResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'created_at' => $this->created_at,
            'sender' => [
                'id' => $this->sender->id,
                'name' => $this->sender->full_name,
                'email' => $this->sender->email,
            ],
            'recipient' => [
                'id' => $this->recipient->id,
                'name' => $this->recipient->full_name,
                'email' => $this->recipient->email,
            ],
            'allocation' => new AllocationResource($this->allocation),
        ];
    }
}