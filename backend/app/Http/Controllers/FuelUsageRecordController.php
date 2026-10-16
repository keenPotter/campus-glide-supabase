<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreFuelUsageRecordRequest;
use App\Http\Requests\UpdateFuelUsageRecordRequest;
use App\Http\Resources\FuelUsageRecordResource;
use App\Models\FuelUsageRecord;
use Illuminate\Http\Request;

class FuelUsageRecordController extends Controller
{
    private const VEHICLE_COLUMNS = 'vehicle:id,plate_number,vehicle_model';

    /**
     * GET /api/fuel-usage-records
     * Query params: ?vehicle_id=3, ?trip_id=5
     */
    public function index(Request $request)
    {
        $query = FuelUsageRecord::with(self::VEHICLE_COLUMNS);

        if ($request->filled('vehicle_id')) {
            $query->where('vehicle_id', $request->integer('vehicle_id'));
        }

        if ($request->filled('trip_id')) {
            $query->where('trip_id', $request->integer('trip_id'));
        }

        return FuelUsageRecordResource::collection($query->orderByDesc('record_date')->get());
    }

    /**
     * POST /api/fuel-usage-records
     */
    public function store(StoreFuelUsageRecordRequest $request)
    {
        $record = FuelUsageRecord::create($request->validated());

        return (new FuelUsageRecordResource($record->load(self::VEHICLE_COLUMNS)))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * PATCH /api/fuel-usage-records/{id}
     */
    public function update(UpdateFuelUsageRecordRequest $request, FuelUsageRecord $fuelUsageRecord)
    {
        $fuelUsageRecord->update($request->validated());

        return new FuelUsageRecordResource($fuelUsageRecord->load(self::VEHICLE_COLUMNS));
    }
}