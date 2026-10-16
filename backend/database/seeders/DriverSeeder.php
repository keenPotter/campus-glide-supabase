<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Drivers are standalone records (not users). Admins pick them when scheduling trips.
 */
class DriverSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'first_name', 'last_name', 'license_number', 'license_expiry_date', 'contact_number',
            'address', 'assigned_vehicle_id', 'is_available', 'created_at', 'updated_at',
        ];

        $drivers = [
            [1, 'Juan',    'Reyes',      'N02-19-012345', '2028-05-14', '09181234503', 'Brgy. Bonfal West, Bayombong, Nueva Vizcaya',        1, true,  '2026-09-01 08:00:00', '2026-09-01 08:00:00'],
            [2, 'Pedro',   'Bautista',   'N02-17-067890', '2027-11-30', '09181234504', 'Brgy. Magsaysay, Bayombong, Nueva Vizcaya',          2, false, '2026-09-01 08:00:00', '2026-10-02 07:10:00'],
            [3, 'Carlos',  'Mendoza',    'N02-15-034567', '2026-11-15', '09181234505', 'Brgy. Don Mariano Marcos, Bayombong, Nueva Vizcaya', 4, true,  '2026-09-01 08:00:00', '2026-09-01 08:00:00'],
            [4, 'Ernesto', 'Villanueva', 'N02-20-045678', '2029-02-20', '09181234506', 'Brgy. Ipil-Cuneg, Bambang, Nueva Vizcaya',          6, false, '2026-09-01 08:00:00', '2026-10-02 07:25:00'],
        ];

        DB::table('drivers')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $drivers)
        );
    }
}