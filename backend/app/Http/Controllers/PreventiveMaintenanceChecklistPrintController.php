<?php

namespace App\Http\Controllers;

use App\Models\PreventiveMaintenanceChecklist;

/**
 * The one place that builds the printable "Preventive Maintenance Checklist".
 * The preventive maintenance page uses it (GET /api/preventive-maintenance-checklists/{id}/print).
 * Administrators only (route middleware).
 */
class PreventiveMaintenanceChecklistPrintController extends Controller
{
    // Items printed in the condition table, in order. "Other parts" is not part of this list.
    private const ITEMS = [
        'belts_condition' => 'Belts',
        'hoses_condition' => 'Hoses',
        'engine_condition' => 'Engine',
        'air_conditioning_condition' => 'Heat / Air conditioning',
        'wipers_condition' => 'Wipers',
        'headlights_condition' => 'Headlights',
        'driving_lights_condition' => 'Driving lights',
        'brake_lights_condition' => 'Brake lights',
        'hazard_lights_condition' => 'Hazard lights',
        'door_locks_condition' => 'Door locks',
        'windows_windshield_condition' => 'Windows / Windshield',
        'radio_condition' => 'Radio',
        'tires_condition' => 'Tires',
        'liquid_levels_condition' => 'Liquid levels',
    ];

    private const SERVICE_DATES = [
        'last_oil_change' => 'Oil change',
        'last_air_filter_change' => 'Air filter',
        'last_cabin_filter_change' => 'Cabin filter',
        'last_oil_filter_change' => 'Oil filter',
        'last_engine_tune_up' => 'Engine tune-up',
    ];

    public function show(PreventiveMaintenanceChecklist $preventiveMaintenanceChecklist)
    {
        $checklist = $preventiveMaintenanceChecklist->load('vehicle');

        $items = [];
        foreach (self::ITEMS as $field => $label) {
            $items[] = ['label' => $label, 'rating' => $checklist->{$field}];
        }

        $serviceDates = [];
        foreach (self::SERVICE_DATES as $field => $label) {
            $serviceDates[] = ['label' => $label, 'value' => $checklist->{$field}?->format('M j, Y') ?? ''];
        }

        return response()->view('print.preventive-maintenance-checklist', [
            'pmuvNo' => $checklist->pmuv_no ?? '',
            'date' => $checklist->inspection_date?->format('M j, Y') ?? '',
            'vehicleModel' => $checklist->vehicle?->vehicle_model ?? '',
            'plateNumber' => $checklist->vehicle?->plate_number ?? '',
            'inspector' => $checklist->inspector_mechanic ?? '',
            'mileage' => $checklist->current_mileage === null
                ? ''
                : number_format($checklist->current_mileage) . ' km',
            'serviceDates' => $serviceDates,
            'items' => $items,
            'otherParts' => $checklist->other_parts ?? '',
            'remarks' => $checklist->remarks ?? '',
            'recommendation' => $checklist->supervisor_recommendation ?? '',
        ]);
    }
}