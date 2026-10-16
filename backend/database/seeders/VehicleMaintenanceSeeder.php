<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class VehicleMaintenanceSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'vehicle_id', 'maintenance_type', 'description', 'maintenance_date',
            'completion_date', 'cost', 'next_due_date', 'performed_by', 'status', 'notes',
            'created_at', 'updated_at',
        ];

        $records = [
            [1,  1, 'oil_change',   'Engine oil and oil filter replacement',      '2026-08-10', '2026-08-10', 3500.00,  '2027-02-10', 'Toyota Santiago Service Center', 'completed',   null,                                              '2026-08-05 09:00:00', '2026-08-10 15:00:00'],
            [2,  2, 'tire_service', 'Replaced four tires and wheel alignment',    '2026-07-15', '2026-07-15', 18400.00, '2027-07-15', 'Bayombong Tire Center',          'completed',   null,                                              '2026-07-10 09:00:00', '2026-07-15 16:00:00'],
            [3,  4, 'repair',       'Clutch assembly replacement',                '2026-09-25', null,         32000.00, null,         'Dela Cruz Auto Repair',          'in_progress', 'Waiting for delivery of clutch disc.',            '2026-09-24 14:00:00', '2026-09-28 10:00:00'],
            [4,  3, 'inspection',   'Semi-annual general inspection',             '2026-06-20', '2026-06-20', 1200.00,  '2026-12-20', 'NVSU Motor Pool Mechanic',       'completed',   null,                                              '2026-06-15 09:00:00', '2026-06-20 12:00:00'],
            [5,  5, 'oil_change',   'Engine oil and filter replacement',          '2026-09-05', '2026-09-05', 2800.00,  '2027-03-05', 'Toyota Santiago Service Center', 'completed',   null,                                              '2026-09-01 09:00:00', '2026-09-05 15:00:00'],
            [6,  6, 'oil_change',   'Engine oil and filter replacement',          '2026-08-25', '2026-08-25', 5200.00,  '2027-02-25', 'Isuzu Cauayan Service Center',   'completed',   null,                                              '2026-08-20 09:00:00', '2026-08-25 14:00:00'],
            [7,  7, 'repair',       'Engine overhaul',                            '2026-03-10', '2026-03-10', 45000.00, null,         'Dela Cruz Auto Repair',          'completed',   'Unit recommended for retirement after overhaul.', '2026-03-01 09:00:00', '2026-03-10 16:00:00'],
            [8,  8, 'oil_change',   'First free service - oil and filter change', '2026-09-12', '2026-09-12', 4100.00,  '2027-03-12', 'Toyota Santiago Service Center', 'completed',   null,                                              '2026-09-08 09:00:00', '2026-09-12 14:00:00'],
            [9,  1, 'tire_service', 'Tire rotation and balancing',                '2026-10-20', null,         null,       null,         null,                             'scheduled',   null,                                              '2026-10-01 09:00:00', '2026-10-01 09:00:00'],
            [10, 3, 'other',        'Air conditioning servicing',                 '2026-05-02', null,         null,       null,         null,                             'cancelled',   'Rescheduled due to parts unavailability.',        '2026-04-28 09:00:00', '2026-05-02 08:00:00'],
            [11, 6, 'inspection',   'Pre-long-trip safety inspection',            '2026-10-15', null,         null,       null,         'NVSU Motor Pool Mechanic',       'scheduled',   null,                                              '2026-10-01 09:30:00', '2026-10-01 09:30:00'],
        ];

        DB::table('vehicle_maintenance')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $records)
        );
    }
}