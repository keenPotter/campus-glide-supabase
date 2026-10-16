<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Reports 1-4 belong to the completed trips. Report 5 is not tied to a trip.
 */
class PostTravelReportSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'vehicle_id', 'trip_id', 'travel_date_from', 'travel_date_to', 'places_of_travel',
            'defects_observed', 'defects_incurred', 'remarks', 'drivers', 'arrival_at',
            'created_at', 'updated_at',
        ];

        $reports = [
            [1, 2, 1,    '2026-09-03', '2026-09-03', 'Bambang - Bayombong - Bambang',      null,                                       null, 'Smooth trip. Vehicle in good running condition.',            'Pedro Bautista',     '2026-09-03 15:40:00', '2026-09-03 16:00:00', '2026-09-03 16:00:00'],
            [2, 8, 2,    '2026-09-08', '2026-09-09', 'Bayombong - Quezon City - Bayombong', 'Slight vibration at high speed.',          null, 'Overnight stay in Quezon City. Wheel alignment recommended.', 'Ernesto Villanueva', '2026-09-09 19:30:00', '2026-09-09 19:50:00', '2026-09-09 19:50:00'],
            [3, 5, 3,    '2026-09-15', '2026-09-15', 'Solano - Bayombong - Solano',        null,                                       null, null,                                                         'Carlos Mendoza',     '2026-09-15 14:20:00', '2026-09-15 14:40:00', '2026-09-15 14:40:00'],
            [4, 1, 4,    '2026-09-22', '2026-09-22', 'Bambang - Solano - Bambang',         'Slight brake noise when stopping.',        null, 'Brake inspection recommended before the next long trip.',    'Juan Reyes',         '2026-09-22 16:40:00', '2026-09-22 17:00:00', '2026-09-22 17:00:00'],
            [5, 3, null, '2026-09-28', null,         'Local errands within Bayombong',     null,                                       null, null,                                                         'Carlos Mendoza',     '2026-09-28 15:30:00', '2026-09-28 15:45:00', '2026-09-28 15:45:00'],
        ];

        DB::table('post_travel_reports')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $reports)
        );
    }
}