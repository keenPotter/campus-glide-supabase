<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreMaintenanceLogRequest;
use App\Http\Requests\UpdateMaintenanceLogRequest;
use App\Http\Resources\MaintenanceLogResource;
use App\Models\VehicleMaintenance;
use Illuminate\Http\Request;

class MaintenanceLogController extends Controller
{
    private const VEHICLE_COLUMNS = 'vehicle:id,plate_number,vehicle_model,mileage';

    /**
     * The API uses the names `type` and `date_performed`.
     * The database columns are `maintenance_type` and `maintenance_date`.
     */
    private const COLUMN_MAP = [
        'type' => 'maintenance_type',
        'date_performed' => 'maintenance_date',
    ];

    /**
     * GET /api/maintenance-logs
     * Query params: ?vehicle_id=3, ?type=repair
     */
    public function index(Request $request)
    {
        $query = VehicleMaintenance::query()->with(self::VEHICLE_COLUMNS);

        if ($request->filled('vehicle_id')) {
            $query->where('vehicle_id', $request->query('vehicle_id'));
        }

        if ($request->filled('type')) {
            $query->where('maintenance_type', $request->query('type'));
        }

        return MaintenanceLogResource::collection($query->orderByDesc('maintenance_date')->get());
    }

    /**
     * POST /api/maintenance-logs
     */
    public function store(StoreMaintenanceLogRequest $request)
    {
        $columns = array_merge(['status' => 'scheduled'], $this->toColumns($request->validated()));

        $log = VehicleMaintenance::create($columns);
        $log->load(self::VEHICLE_COLUMNS);

        $this->syncVehicleDates($log);

        return (new MaintenanceLogResource($log->fresh(self::VEHICLE_COLUMNS)))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * PATCH /api/maintenance-logs/{id}
     */
    public function update(UpdateMaintenanceLogRequest $request, VehicleMaintenance $maintenanceLog)
    {
        $maintenanceLog->update($this->toColumns($request->validated()));
        $maintenanceLog->load(self::VEHICLE_COLUMNS);

        $this->syncVehicleDates($maintenanceLog);

        return new MaintenanceLogResource($maintenanceLog);
    }

    /**
     * Rename API field names to database column names.
     */
    private function toColumns(array $validated): array
    {
        $columns = [];

        foreach ($validated as $key => $value) {
            $columns[self::COLUMN_MAP[$key] ?? $key] = $value;
        }

        return $columns;
    }

    /**
     * Keep the vehicle's own maintenance dates in sync,
     * but only when this log is the vehicle's latest one.
     */
    private function syncVehicleDates(VehicleMaintenance $log): void
    {
        $vehicle = $log->vehicle;

        if ($vehicle->latestMaintenanceLog?->is($log)) {
            $vehicle->update([
                'last_maintenance_date' => $log->maintenance_date->toDateString(),
                'next_maintenance_date' => $log->next_due_date?->toDateString(),
            ]);
        }
    }
}