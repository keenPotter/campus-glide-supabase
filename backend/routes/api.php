<?php

use App\Http\Controllers\AllocationController;
use App\Http\Controllers\AllocationPrintController;
use App\Http\Controllers\AllocationQuickAddController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\DriverController;
use App\Http\Controllers\FuelUsageRecordController;
use App\Http\Controllers\MaintenanceLogController;
use App\Http\Controllers\PostTravelReportController;
use App\Http\Controllers\PreventiveMaintenanceChecklistController;
use App\Http\Controllers\PreventiveMaintenanceChecklistPrintController;
use App\Http\Controllers\RescheduleRequestController;
use App\Http\Controllers\TripController;
use App\Http\Controllers\TripRequestShareController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\VehicleController;
use App\Http\Controllers\VehicleRequestController;
use Illuminate\Support\Facades\Route;

// ---------- Public ----------
// Login is the only route that can be used without a token.
// The throttle allows 10 attempts per minute to slow down password guessing.
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

// ---------- Authenticated (every route below needs a valid token) ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [AuthController::class, 'user']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Everyone who is logged in can list/view; scoping happens inside the controller
    Route::get('/vehicle-requests', [VehicleRequestController::class, 'index']);
    Route::get('/vehicle-requests/{vehicleRequest}', [VehicleRequestController::class, 'show'])
        ->whereNumber('vehicleRequest');

    // Allocations and date change requests: administrators see all, faculty see only their own
    Route::get('/allocations', [AllocationController::class, 'index']);
    Route::get('/allocations/{allocation}', [AllocationController::class, 'show'])
        ->whereNumber('allocation');
    Route::get('/reschedule-requests', [RescheduleRequestController::class, 'index']);

    // ---------- Faculty only ----------
    Route::middleware('role:faculty')->group(function () {
        Route::post('/vehicle-requests', [VehicleRequestController::class, 'store']);
        Route::put('/vehicle-requests/{vehicleRequest}/edit', [VehicleRequestController::class, 'edit']);
        Route::get('/my-trips', [TripController::class, 'myTrips']);

        // Faculty ask for a date change; the administrator decides.
        Route::post('/allocations/{allocation}/reschedule-requests', [RescheduleRequestController::class, 'store'])
            ->whereNumber('allocation');
    });

    // ---------- Administrator only ----------
    Route::middleware('role:administrator')->group(function () {
        // Accounts
        Route::post('/register', [AuthController::class, 'register']);
        Route::get('/users', [UserController::class, 'index']);

        // Vehicle request approval
        Route::patch('/vehicle-requests/{vehicleRequest}/status', [VehicleRequestController::class, 'updateStatus']);

        // Approved requests waiting to be scheduled ('whereNumber' on the show route keeps "approved" from being read as an ID).
        Route::get('/vehicle-requests/approved', [VehicleRequestController::class, 'approved']);

        // Trips are read-only here. New trips are created through allocations (see below).
        Route::get('/trips', [TripController::class, 'index']);
        Route::get('/trips/{trip}', [TripController::class, 'show'])
            ->whereNumber('trip');

        // Vehicle-driver allocation
        // A pending request is approved and assigned in one step: POST /allocations with approve_request = true.
        Route::get('/allocation-options', [AllocationController::class, 'options']);
        Route::post('/allocations', [AllocationController::class, 'store']);
        Route::put('/allocations/{allocation}', [AllocationController::class, 'update'])
            ->whereNumber('allocation');
        Route::get('/allocations/{allocation}/print', [AllocationPrintController::class, 'show'])
            ->whereNumber('allocation');
        Route::post('/allocation-drivers', [AllocationQuickAddController::class, 'storeDriver']);
        Route::post('/allocation-vehicles', [AllocationQuickAddController::class, 'storeVehicle']);

        // Date changes: reassign the date directly, or approve / disapprove a faculty request.
        Route::post('/allocations/{allocation}/reschedule', [RescheduleRequestController::class, 'reschedule'])
            ->whereNumber('allocation');
        Route::post('/reschedule-requests/{rescheduleRequest}/approve', [RescheduleRequestController::class, 'approve'])
            ->whereNumber('rescheduleRequest');
        Route::post('/reschedule-requests/{rescheduleRequest}/disapprove', [RescheduleRequestController::class, 'disapprove'])
            ->whereNumber('rescheduleRequest');
        
        // Sending a trip request to another administrator
        Route::get('/admins', [TripRequestShareController::class, 'admins']);
        Route::get('/trip-request-shares', [TripRequestShareController::class, 'index']);
        Route::post('/trip-request-shares', [TripRequestShareController::class, 'store']);

        // Driver list.
        Route::get('/drivers', [DriverController::class, 'index']);

        // Vehicles (the trip schedule and maintenance pages both read this).
        Route::get('/vehicles', [VehicleController::class, 'index']);
        Route::get('/vehicles/{vehicle}/status', [VehicleController::class, 'status']);

        // Maintenance Monitoring
        Route::get('/maintenance-logs', [MaintenanceLogController::class, 'index']);
        Route::post('/maintenance-logs', [MaintenanceLogController::class, 'store']);
        Route::patch('/maintenance-logs/{maintenanceLog}', [MaintenanceLogController::class, 'update']);

        // Fleet forms captured from the NVSU Motor Pool documents.
        Route::get('/post-travel-reports', [PostTravelReportController::class, 'index']);
        Route::post('/post-travel-reports', [PostTravelReportController::class, 'store']);
        Route::patch('/post-travel-reports/{postTravelReport}', [PostTravelReportController::class, 'update']);

        Route::get('/fuel-usage-records', [FuelUsageRecordController::class, 'index']);
        Route::post('/fuel-usage-records', [FuelUsageRecordController::class, 'store']);
        Route::patch('/fuel-usage-records/{fuelUsageRecord}', [FuelUsageRecordController::class, 'update']);

        Route::get('/preventive-maintenance-checklists', [PreventiveMaintenanceChecklistController::class, 'index']);
        Route::post('/preventive-maintenance-checklists', [PreventiveMaintenanceChecklistController::class, 'store']);
        Route::patch('/preventive-maintenance-checklists/{preventiveMaintenanceChecklist}', [PreventiveMaintenanceChecklistController::class, 'update']);
        // The printable checklist (legal size), built by the backend.
        Route::get('/preventive-maintenance-checklists/{preventiveMaintenanceChecklist}/print', [PreventiveMaintenanceChecklistPrintController::class, 'show'])
            ->whereNumber('preventiveMaintenanceChecklist');
    });
});