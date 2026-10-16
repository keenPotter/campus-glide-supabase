<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * One allocation record per trip: who assigned which vehicle and driver, and when.
 * The vehicle and driver here are the same as on the trip.
 */
class AllocationSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'trip_id', 'vehicle_id', 'driver_id', 'allocated_by', 'allocation_date',
            'notes', 'created_at', 'updated_at',
        ];

        $allocations = [
            [1, 1, 2, 2, 1, '2026-08-31 11:00:00', null,                                          '2026-08-31 11:00:00', '2026-08-31 11:00:00'],
            [2, 2, 8, 4, 2, '2026-09-04 10:30:00', 'Overnight stay in Quezon City.',               '2026-09-04 10:30:00', '2026-09-04 10:30:00'],
            [3, 3, 5, 3, 1, '2026-09-10 15:00:00', null,                                          '2026-09-10 15:00:00', '2026-09-10 15:00:00'],
            [4, 4, 1, 1, 2, '2026-09-18 12:00:00', null,                                          '2026-09-18 12:00:00', '2026-09-18 12:00:00'],
            [5, 5, 2, 2, 1, '2026-10-08 10:30:00', null,                                          '2026-10-08 10:30:00', '2026-10-08 10:30:00'],
            [6, 6, 6, 4, 2, '2026-10-08 11:00:00', null,                                          '2026-10-08 11:00:00', '2026-10-08 11:00:00'],
            [7, 7, 8, 1, 1, '2026-10-07 11:00:00', 'Overnight stay in Manila.',                   '2026-10-07 11:00:00', '2026-10-07 11:00:00'],
            [8, 8, 1, 3, 2, '2026-10-09 10:00:00', 'Passengers will gather at the main gate.',    '2026-10-09 10:00:00', '2026-10-09 10:00:00'],
        ];

        DB::table('allocations')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $allocations)
        );
    }
}