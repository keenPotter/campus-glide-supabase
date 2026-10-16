<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\Vehicle;
use App\Services\AllocationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * "Add new driver" and "Add new vehicle" from the allocation page.
 * Administrators only (route middleware).
 */
class AllocationQuickAddController extends Controller
{
    /**
     * POST /api/allocation-drivers
     */
    public function storeDriver(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            // Column length is 20 in the drivers table.
            'contact_number' => ['required', 'string', 'max:20'],
            'license_number' => ['required', 'string', 'max:50', 'unique:drivers,license_number'],
            'license_expiry_date' => ['required', 'date_format:Y-m-d'],
        ]);

        // The drivers table keeps first and last name in separate columns.
        // The last word is the last name. A single word is used for both.
        $parts = preg_split('/\s+/', trim($validated['name']));
        $lastName = count($parts) > 1 ? array_pop($parts) : $parts[0];
        $firstName = implode(' ', $parts);

        $driver = Driver::create([
            'first_name' => $firstName,
            'last_name' => $lastName,
            'contact_number' => $validated['contact_number'],
            'license_number' => $validated['license_number'],
            'license_expiry_date' => $validated['license_expiry_date'],
            'is_available' => true,
        ]);

        return response()->json(['data' => AllocationService::driverOption($driver)], 201);
    }

    /**
     * POST /api/allocation-vehicles
     */
    public function storeVehicle(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'plate_number' => ['required', 'string', 'max:20', 'unique:vehicles,plate_number'],
            'vehicle_model' => ['required', 'string', 'max:100'],
            'vehicle_type' => ['nullable', 'string', 'max:50'],
            'capacity' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $vehicle = Vehicle::create([
            ...$validated,
            // vehicle_type is required in the table, but the quick-add form does not ask for it.
            'vehicle_type' => $validated['vehicle_type'] ?? 'Not specified',
            'status' => 'available',
            'is_active' => true,
        ]);

        return response()->json(['data' => AllocationService::vehicleOption($vehicle)], 201);
    }
}