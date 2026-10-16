<?php

namespace App\Http\Controllers;

use App\Http\Requests\StorePostTravelReportRequest;
use App\Http\Requests\UpdatePostTravelReportRequest;
use App\Http\Resources\PostTravelReportResource;
use App\Models\PostTravelReport;
use Illuminate\Http\Request;

class PostTravelReportController extends Controller
{
    private const VEHICLE_COLUMNS = 'vehicle:id,plate_number,vehicle_model';

    /**
     * GET /api/post-travel-reports
     * Query params: ?vehicle_id=3
     */
    public function index(Request $request)
    {
        $query = PostTravelReport::with(self::VEHICLE_COLUMNS);

        if ($request->filled('vehicle_id')) {
            $query->where('vehicle_id', $request->integer('vehicle_id'));
        }

        return PostTravelReportResource::collection($query->orderByDesc('travel_date_from')->get());
    }

    /**
     * POST /api/post-travel-reports
     */
    public function store(StorePostTravelReportRequest $request)
    {
        $report = PostTravelReport::create($request->validated());

        return (new PostTravelReportResource($report->load(self::VEHICLE_COLUMNS)))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * PATCH /api/post-travel-reports/{id}
     */
    public function update(UpdatePostTravelReportRequest $request, PostTravelReport $postTravelReport)
    {
        $postTravelReport->update($request->validated());

        return new PostTravelReportResource($postTravelReport->load(self::VEHICLE_COLUMNS));
    }
}