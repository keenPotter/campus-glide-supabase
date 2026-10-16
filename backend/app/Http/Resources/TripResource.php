<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The field names match what the frontend trip schedule pages read
 * (vehicle_request, vehicle, driver).
 */
class TripResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $vehicleRequest = $this->vehicleRequest;
        $requester = $vehicleRequest?->requester;

        return [
            'id' => $this->id,
            'vehicle_request_id' => $this->vehicle_request_id,
            'vehicle_id' => $this->vehicle_id,
            'driver_id' => $this->driver_id,
            'trip_date' => $this->trip_date?->toDateString(),
            'departure_time' => $this->departure_time,
            'estimated_return_time' => $this->estimated_return_time,
            'destination' => $this->destination,
            'purpose' => $this->purpose,
            'trip_status' => $this->trip_status,
            'actual_departure_time' => $this->actual_departure_time,
            'actual_return_time' => $this->actual_return_time,
            'actual_mileage' => $this->actual_mileage,
            'notes' => $this->notes,
            'vehicle_request' => $vehicleRequest ? [
                'id' => $vehicleRequest->id,
                'status' => $vehicleRequest->status,
                'trip_type' => $vehicleRequest->trip_type,
                'trip_date' => $vehicleRequest->trip_date?->toDateString(),
                'trip_end_date' => $vehicleRequest->trip_end_date?->toDateString(),
                'number_of_passengers' => $vehicleRequest->number_of_passengers,
                'requester' => $requester ? [
                    'id' => $requester->id,
                    'first_name' => $requester->first_name,
                    'last_name' => $requester->last_name,
                ] : null,
            ] : null,
            'vehicle' => $this->vehicle ? [
                'id' => $this->vehicle->id,
                'plate_number' => $this->vehicle->plate_number,
                'vehicle_model' => $this->vehicle->vehicle_model,
            ] : null,
            'driver' => $this->driver ? [
                'id' => $this->driver->id,
                'first_name' => $this->driver->first_name,
                'last_name' => $this->driver->last_name,
                'name' => $this->driver->full_name,
                'contact_number' => $this->driver->contact_number,
            ] : null,
        ];
    }
}