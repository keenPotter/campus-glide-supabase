<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * One trip per approved request that already has a vehicle and driver (requests 1-8).
 * Request 9 has no trip yet, so it shows up as "Needs allocation".
 * Trips 5 and 6 are in progress today and match the vehicles (2, 6) and drivers (2, 4)
 * that are marked "in use" / unavailable in VehicleSeeder and DriverSeeder.
 */
class TripSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'vehicle_request_id', 'vehicle_id', 'driver_id', 'trip_date', 'departure_time',
            'estimated_return_time', 'destination', 'purpose', 'trip_status',
            'actual_departure_time', 'actual_return_time', 'actual_mileage', 'notes',
            'created_at', 'updated_at',
        ];

        $trips = [
            [1, 1, 2, 2, '2026-09-03', '08:00:00', '16:00:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Faculty general assembly and department meeting', 'completed', '08:05:00', '15:40:00', 45, null, '2026-08-31 11:00:00', '2026-09-03 15:45:00'],
            [2, 2, 8, 4, '2026-09-08', '05:00:00', '20:00:00', 'Office of the Congressman, House of Representatives, Quezon City, Metro Manila', 'Meeting with the congressman on the university budget and infrastructure projects', 'completed', '05:10:00', '19:30:00', 690, 'Two-day trip, overnight stay in Quezon City.', '2026-09-04 10:30:00', '2026-09-09 19:35:00'],
            [3, 3, 5, 3, '2026-09-15', '09:00:00', '15:00:00', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Coordination meeting with provincial officials on extension programs', 'completed', '09:05:00', '14:20:00', 24, null, '2026-09-10 15:00:00', '2026-09-15 14:25:00'],
            [4, 4, 1, 1, '2026-09-22', '08:30:00', '17:00:00', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with municipal officials on community partnership', 'completed', '08:35:00', '16:40:00', 62, null, '2026-09-18 12:00:00', '2026-09-22 16:45:00'],
            [5, 5, 2, 2, '2026-10-12', '07:30:00', '16:30:00', 'Office of the Congressman, Bayombong, Nueva Vizcaya', 'Meeting with the congressman and staff on the scholarship program', 'in_progress', '07:35:00', null, null, null, '2026-10-08 10:30:00', '2026-10-12 07:35:00'],
            [6, 6, 6, 4, '2026-10-12', '08:00:00', '15:00:00', 'DepEd Schools Division Office, Bayombong, Nueva Vizcaya', 'Meeting with DepEd officials on the senior high school partnership', 'in_progress', '08:05:00', null, null, null, '2026-10-08 11:00:00', '2026-10-12 08:05:00'],
            [7, 7, 8, 1, '2026-10-15', '05:00:00', '20:00:00', 'Department of Budget and Management, Manila', 'Meeting with DBM officials on the proposed university budget', 'scheduled', null, null, null, 'Two-day trip, overnight stay in Manila.', '2026-10-07 11:00:00', '2026-10-07 11:00:00'],
            [8, 8, 1, 3, '2026-10-21', '09:00:00', '16:00:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Academic council meeting of all campus faculty', 'scheduled', null, null, null, null, '2026-10-09 10:00:00', '2026-10-09 10:00:00'],
        ];

        DB::table('trips')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $trips)
        );
    }
}