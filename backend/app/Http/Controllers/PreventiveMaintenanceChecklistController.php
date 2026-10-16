<?php

namespace App\Http\Controllers;

use App\Http\Requests\StorePreventiveMaintenanceChecklistRequest;
use App\Http\Requests\UpdatePreventiveMaintenanceChecklistRequest;
use App\Http\Resources\PreventiveMaintenanceChecklistResource;
use App\Models\PreventiveMaintenanceChecklist;
use Illuminate\Http\Request;

class PreventiveMaintenanceChecklistController extends Controller
{
    private const VEHICLE_COLUMNS = 'vehicle:id,plate_number,vehicle_model';

    /**
     * GET /api/preventive-maintenance-checklists
     * Query params: ?vehicle_id=3
     */
    public function index(Request $request)
    {
        $query = PreventiveMaintenanceChecklist::with(self::VEHICLE_COLUMNS);

        if ($request->filled('vehicle_id')) {
            $query->where('vehicle_id', $request->integer('vehicle_id'));
        }

        return PreventiveMaintenanceChecklistResource::collection($query->orderByDesc('inspection_date')->get());
    }

    /**
     * POST /api/preventive-maintenance-checklists
     */
    public function store(StorePreventiveMaintenanceChecklistRequest $request)
    {
        $checklist = PreventiveMaintenanceChecklist::create($request->validated());

        return (new PreventiveMaintenanceChecklistResource($checklist->load(self::VEHICLE_COLUMNS)))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * PATCH /api/preventive-maintenance-checklists/{id}
     */
    public function update(UpdatePreventiveMaintenanceChecklistRequest $request, PreventiveMaintenanceChecklist $preventiveMaintenanceChecklist)
    {
        $preventiveMaintenanceChecklist->update($request->validated());

        return new PreventiveMaintenanceChecklistResource($preventiveMaintenanceChecklist->load(self::VEHICLE_COLUMNS));
    }
}