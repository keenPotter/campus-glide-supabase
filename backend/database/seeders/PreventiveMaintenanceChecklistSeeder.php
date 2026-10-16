<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class PreventiveMaintenanceChecklistSeeder extends Seeder
{
    /**
     * Order matches the `ratings` arrays below.
     */
    private const RATING_COLUMNS = [
        'belts_condition', 'hoses_condition', 'engine_condition',
        'air_conditioning_condition', 'wipers_condition',
        'headlights_condition', 'driving_lights_condition',
        'brake_lights_condition', 'hazard_lights_condition',
        'door_locks_condition', 'windows_windshield_condition',
        'radio_condition', 'tires_condition', 'liquid_levels_condition',
        'other_parts_condition',
    ];

    public function run(): void
    {
        $records = [
            [
                'id' => 1, 'vehicle_id' => 1, 'pmuv_no' => 'PMUV-2026-001', 'inspection_date' => '2026-08-10',
                'inspector_mechanic' => 'Rodel Quiambao', 'current_mileage' => 84500,
                'last_oil_change' => '2026-08-10', 'last_air_filter_change' => '2026-08-10',
                'last_cabin_filter_change' => '2026-02-10', 'last_oil_filter_change' => '2026-08-10',
                'last_engine_tune_up' => '2026-02-10',
                'ratings' => ['good', 'good', 'excellent', 'good', 'good', 'excellent', 'good', 'excellent', 'excellent', 'good', 'good', 'good', 'good', 'excellent', 'good'],
                'other_parts' => null,
                'remarks' => 'Vehicle in good overall condition.',
                'supervisor_recommendation' => 'Continue regular maintenance schedule.',
                'created_at' => '2026-08-10 15:30:00', 'updated_at' => '2026-08-10 15:30:00',
            ],
            [
                'id' => 2, 'vehicle_id' => 2, 'pmuv_no' => 'PMUV-2026-002', 'inspection_date' => '2026-07-15',
                'inspector_mechanic' => 'Rodel Quiambao', 'current_mileage' => 61200,
                'last_oil_change' => '2026-05-15', 'last_air_filter_change' => '2026-05-15',
                'last_cabin_filter_change' => '2026-01-15', 'last_oil_filter_change' => '2026-05-15',
                'last_engine_tune_up' => '2026-01-15',
                'ratings' => ['good', 'good', 'good', 'excellent', 'poor', 'good', 'good', 'good', 'good', 'excellent', 'good', 'excellent', 'excellent', 'good', 'good'],
                'other_parts' => null,
                'remarks' => 'Wipers worn out; tires newly replaced.',
                'supervisor_recommendation' => 'Replace wiper blades at next opportunity.',
                'created_at' => '2026-07-15 16:30:00', 'updated_at' => '2026-07-15 16:30:00',
            ],
            [
                'id' => 3, 'vehicle_id' => 3, 'pmuv_no' => 'PMUV-2026-003', 'inspection_date' => '2026-06-20',
                'inspector_mechanic' => 'Rodel Quiambao', 'current_mileage' => 102300,
                'last_oil_change' => '2026-03-20', 'last_air_filter_change' => '2025-12-20',
                'last_cabin_filter_change' => null, 'last_oil_filter_change' => '2026-03-20',
                'last_engine_tune_up' => '2025-12-20',
                'ratings' => ['good', 'poor', 'good', 'poor', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'poor', 'good', 'good', 'good'],
                'other_parts' => 'Radiator hose slightly cracked',
                'remarks' => 'Hoses and air conditioning need attention.',
                'supervisor_recommendation' => 'Replace radiator hose and schedule AC servicing.',
                'created_at' => '2026-06-20 12:30:00', 'updated_at' => '2026-06-20 12:30:00',
            ],
            [
                'id' => 4, 'vehicle_id' => 4, 'pmuv_no' => 'PMUV-2026-004', 'inspection_date' => '2026-09-25',
                'inspector_mechanic' => 'Efren Dela Cruz', 'current_mileage' => 156800,
                'last_oil_change' => '2026-04-18', 'last_air_filter_change' => '2026-04-18',
                'last_cabin_filter_change' => '2025-10-18', 'last_oil_filter_change' => '2026-04-18',
                'last_engine_tune_up' => '2025-10-18',
                'ratings' => ['poor', 'good', 'poor', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'poor'],
                'other_parts' => 'Clutch assembly worn',
                'remarks' => 'Unit undergoing clutch replacement. Belts and engine need follow-up check.',
                'supervisor_recommendation' => 'Do not release unit until repairs are completed and re-inspected.',
                'created_at' => '2026-09-25 11:00:00', 'updated_at' => '2026-09-25 11:00:00',
            ],
            [
                'id' => 5, 'vehicle_id' => 5, 'pmuv_no' => 'PMUV-2026-005', 'inspection_date' => '2026-09-05',
                'inspector_mechanic' => 'Rodel Quiambao', 'current_mileage' => 38900,
                'last_oil_change' => '2026-09-05', 'last_air_filter_change' => '2026-09-05',
                'last_cabin_filter_change' => '2026-03-05', 'last_oil_filter_change' => '2026-09-05',
                'last_engine_tune_up' => '2026-03-05',
                'ratings' => ['excellent', 'excellent', 'excellent', 'excellent', 'good', 'excellent', 'excellent', 'excellent', 'excellent', 'excellent', 'excellent', 'good', 'excellent', 'excellent', 'excellent'],
                'other_parts' => null,
                'remarks' => 'Excellent condition.',
                'supervisor_recommendation' => 'No action needed.',
                'created_at' => '2026-09-05 15:30:00', 'updated_at' => '2026-09-05 15:30:00',
            ],
            [
                'id' => 6, 'vehicle_id' => 7, 'pmuv_no' => 'PMUV-2026-006', 'inspection_date' => '2026-03-10',
                'inspector_mechanic' => 'Efren Dela Cruz', 'current_mileage' => 189000,
                'last_oil_change' => '2025-11-02', 'last_air_filter_change' => '2025-06-02',
                'last_cabin_filter_change' => null, 'last_oil_filter_change' => '2025-11-02',
                'last_engine_tune_up' => '2025-06-02',
                'ratings' => ['poor', 'poor', 'poor', 'poor', 'poor', 'poor', 'good', 'poor', 'good', 'poor', 'poor', 'poor', 'poor', 'poor', 'poor'],
                'other_parts' => 'Chassis corrosion',
                'remarks' => 'Vehicle beyond economical repair.',
                'supervisor_recommendation' => 'Recommend retirement of unit.',
                'created_at' => '2026-03-10 16:30:00', 'updated_at' => '2026-03-10 16:30:00',
            ],
        ];

        $rows = array_map(function (array $record) {
            $ratings = $record['ratings'];
            unset($record['ratings']);

            return $record + array_combine(self::RATING_COLUMNS, $ratings);
        }, $records);

        DB::table('preventive_maintenance_checklists')->insert($rows);
    }
}