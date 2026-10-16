<?php

namespace App\Http\Resources;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AllocationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $trip = $this->trip;
        $vehicleRequest = $trip?->vehicleRequest;

        return [
            'id' => $this->id,
            'status' => $trip?->trip_status,
            'trip' => [
                'id' => $trip?->id,
                'trip_date' => $trip?->trip_date ? Carbon::parse($trip->trip_date)->toDateString() : null,
                // The last day of the trip (the end date is kept on the vehicle request).
                'trip_end_date' => $vehicleRequest?->trip_end_date
                    ? Carbon::parse($vehicleRequest->trip_end_date)->toDateString()
                    : ($trip?->trip_date ? Carbon::parse($trip->trip_date)->toDateString() : null),
                'departure_time' => $trip?->departure_time,
                'estimated_return_time' => $trip?->estimated_return_time,
                'destination' => $trip?->destination,
                'purpose' => $trip?->purpose,
            ],
            'vehicle_request' => [
                'id' => $vehicleRequest?->id,
                // The frontend shows the print button only for an approved request.
                'status' => $vehicleRequest?->status,
                // The frontend filters allocations by trip type.
                'trip_type' => $vehicleRequest?->trip_type,
                'requester' => $vehicleRequest?->requester?->full_name,
                // Shown in the allocation summary table.
                'number_of_passengers' => $vehicleRequest?->number_of_passengers,
            ],
            'vehicle' => [
                'id' => $this->vehicle?->id,
                'plate_number' => $this->vehicle?->plate_number,
                'vehicle_model' => $this->vehicle?->vehicle_model,
            ],
            // A driver is a record only (no login): name, contact number and license.
            'driver' => [
                'id' => $this->driver?->id,
                'name' => $this->driver?->full_name,
                'contact_number' => $this->driver?->contact_number,
                'license_number' => $this->driver?->license_number,
            ],
            'allocated_by' => $this->allocatedBy?->full_name,
            'allocation_date' => $this->allocation_date,
            'notes' => $this->notes,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}