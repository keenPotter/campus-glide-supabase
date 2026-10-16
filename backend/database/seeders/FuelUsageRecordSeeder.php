<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * end_trip_balance = balance_in_tank + issuance_from_stock + fuel_purchased - fuel_used
 * Records 1-4 belong to the completed trips. Records 5-6 are not tied to a trip.
 */
class FuelUsageRecordSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'vehicle_id', 'trip_id', 'record_date', 'balance_in_tank', 'issuance_from_stock',
            'fuel_purchased', 'fuel_used', 'end_trip_balance', 'riv_no', 'riv_date', 'or_no', 'or_date',
            'lubricating_oil', 'diesel_water', 'gear_oil', 'brake_fluid', 'flushing_oil', 'grease',
            'drivers', 'created_at', 'updated_at',
        ];

        $records = [
            [1, 2, 1,    '2026-09-03', 18.00, 20.00, 0.00,  5.00,  33.00, 'RIV-2026-0210', '2026-09-02', null,        null,         null, null, null, null, null, null, 'Pedro Bautista',     '2026-09-03 16:00:00', '2026-09-03 16:00:00'],
            [2, 8, 2,    '2026-09-09', 45.00, 40.00, 30.00, 77.00, 38.00, 'RIV-2026-0214', '2026-09-07', 'OR-612045', '2026-09-08', 1.00, null, null, null, null, null, 'Ernesto Villanueva', '2026-09-09 19:50:00', '2026-09-09 19:50:00'],
            [3, 5, 3,    '2026-09-15', 20.00, 0.00,  0.00,  2.50,  17.50, null,            null,         null,        null,         null, null, null, null, null, null, 'Carlos Mendoza',     '2026-09-15 14:40:00', '2026-09-15 14:40:00'],
            [4, 1, 4,    '2026-09-22', 22.00, 15.00, 0.00,  8.00,  29.00, 'RIV-2026-0226', '2026-09-21', null,        null,         null, null, null, null, null, null, 'Juan Reyes',         '2026-09-22 17:00:00', '2026-09-22 17:00:00'],
            [5, 3, null, '2026-09-28', 10.00, 20.00, 0.00,  4.00,  26.00, 'RIV-2026-0233', '2026-09-27', null,        null,         null, null, null, null, null, null, 'Carlos Mendoza',     '2026-09-28 15:45:00', '2026-09-28 15:45:00'],
            [6, 6, null, '2026-10-01', 12.00, 0.00,  40.00, 5.00,  47.00, null,            null,         'OR-613380', '2026-10-01', null, null, null, null, null, null, 'Ernesto Villanueva', '2026-10-01 16:00:00', '2026-10-01 16:00:00'],
        ];

        DB::table('fuel_usage_records')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $records)
        );
    }
}