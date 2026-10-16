<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class VehicleSeeder extends Seeder
{
    public function run(): void
    {
        $columns = [
            'id', 'plate_number', 'vehicle_model', 'vehicle_type', 'color', 'manufacture_year',
            'capacity', 'mileage', 'status', 'last_maintenance_date', 'next_maintenance_date',
            'is_active', 'created_at', 'updated_at',
        ];

        $vehicles = [
            [1, 'SAA 1234', 'Toyota Hiace Commuter', 'Van',         'White',       2019, 15, 84500,  'available',   '2026-08-10', '2027-02-10', true,  '2026-09-01 08:00:00', '2026-09-01 08:00:00'],
            [2, 'NBC 5521', 'Toyota Innova',         'MPV',         'Silver',      2020, 7,  61200,  'in_use',      '2026-07-15', '2027-01-15', true,  '2026-09-01 08:00:00', '2026-10-02 07:10:00'],
            [3, 'NAB 7712', 'Mitsubishi L300 FB',    'Utility Van', 'White',       2018, 3,  102300, 'available',   '2026-06-20', '2026-12-20', true,  '2026-09-01 08:00:00', '2026-09-01 08:00:00'],
            [4, 'NCD 3345', 'Toyota Coaster',        'Bus',         'White',       2017, 30, 156800, 'maintenance', '2026-04-18', '2026-10-18', true,  '2026-09-01 08:00:00', '2026-09-25 09:00:00'],
            [5, 'AEF 6098', 'Toyota Vios',           'Sedan',       'Black',       2021, 4,  38900,  'available',   '2026-09-05', '2027-03-05', true,  '2026-09-01 08:00:00', '2026-09-05 15:00:00'],
            [6, 'NGH 2271', 'Isuzu D-Max',           'Pickup',      'Gray',        2022, 5,  27400,  'in_use',      '2026-08-25', '2027-02-25', true,  '2026-09-01 08:00:00', '2026-10-02 07:25:00'],
            [7, 'ABK 4410', 'Nissan Urvan NV350',    'Van',         'Silver',      2016, 14, 189000, 'retired',     '2025-11-02', null,         false, '2026-09-01 08:00:00', '2026-03-10 16:00:00'],
            [8, 'NLM 8830', 'Toyota Fortuner',       'SUV',         'Pearl White', 2023, 7,  15600,  'available',   '2026-09-12', '2027-03-12', true,  '2026-09-01 08:00:00', '2026-09-12 14:00:00'],
        ];

        DB::table('vehicles')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $vehicles)
        );
    }
}