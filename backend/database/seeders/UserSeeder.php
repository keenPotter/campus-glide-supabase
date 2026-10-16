<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * IDs: 1-2 administrators | 3-12 faculty (10 is the University President)
 * The administrators are the Chief, Motorpool and the Unit Head-GSU printed on the request form.
 * All passwords = "password"
 */
class UserSeeder extends Seeder
{
    public function run(): void
    {
        $password = Hash::make('password');
        $ts = '2026-09-01 08:00:00';

        $columns = [
            'id', 'email', 'password', 'first_name', 'last_name', 'position',
            'phone_number', 'role', 'is_active', 'created_at', 'updated_at',
        ];

        $users = [
            [1,  'tony.basatan@nvsu.edu.ph',     'Tony O.',         'Basatan',    'Chief, Motorpool',    '09171234501', 'administrator', true],
            [2,  'jayson.pimentel@nvsu.edu.ph',  'Jayson R.',       'Pimentel',   'Unit Head-GSU',       '09171234502', 'administrator', true],
            [3,  'marife.aliaga@nvsu.edu.ph',    'Marife',          'Aliaga',     'Professor',           '09201234503', 'faculty',       true],
            [4,  'vernyll.asis@nvsu.edu.ph',     'Vernyll Jan',     'Asis',       'Assistant Professor', '09201234504', 'faculty',       true],
            [5,  'krizsha.salinas@nvsu.edu.ph',  'Krizsha Ellaine', 'Salinas',    'Associate Professor', '09201234505', 'faculty',       true],
            [6,  'dennis.directo@nvsu.edu.ph',   'Dennis',          'Directo',    'Instructor',          '09201234506', 'faculty',       true],
            [7,  'mark.viernes@nvsu.edu.ph',     'Mark John',       'Viernes',    'Assistant Professor', '09201234507', 'faculty',       true],
            [8,  'gwen.gagasa@nvsu.edu.ph',      'Gwen Kyle',       'Gagasa',     'Instructor',          '09201234508', 'faculty',       true],
            [9,  'percival.labog@nvsu.edu.ph',   'Percival',        'Labog',      'Associate Professor', '09201234509', 'faculty',       true],
            [10, 'wilfredo.dumale@nvsu.edu.ph',  'Wilfredo',        'Dumale Jr.', 'University President', '09201234510', 'faculty',       true],
            [11, 'gerals.perez@nvsu.edu.ph',     'Gerals',          'Perez',      'Professor',           '09201234511', 'faculty',       true],
            [12, 'arnel.agustin@nvsu.edu.ph',    'Arnel',           'Agustin',    'Instructor',          '09201234512', 'faculty',       true],
        ];

        $rows = array_map(
            fn (array $u) => array_combine($columns, [
                $u[0], $u[1], $password, $u[2], $u[3], $u[4], $u[5], $u[6], $u[7], $ts, $ts,
            ]),
            $users
        );

        DB::table('users')->insert($rows);
    }
}