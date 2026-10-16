<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * 1-4   approved, trip completed
 * 5-6   approved, trip in progress today (2026-10-12)
 * 7-8   approved, trip scheduled
 * 9     approved, waiting for a vehicle and driver
 * 10-17 pending
 * 18-25 disapproved
 *
 * Inclusive = inside Nueva Vizcaya. Exclusive = outside Nueva Vizcaya (requested by the president).
 */
class VehicleRequestSeeder extends Seeder
{
    private const MAIN = 'NVSU Main Campus, Bayombong, Nueva Vizcaya';
    private const CAPITOL = 'Provincial Capitol, Bayombong, Nueva Vizcaya';
    private const CONGRESSMAN = 'Office of the Congressman, Bayombong, Nueva Vizcaya';

    private const MAINTENANCE = 'The vehicle needed for this trip is under maintenance on the requested date.';
    private const NO_AVAILABLE = 'No available driver or vehicle on the requested date.';
    private const NO_DATE = 'The requested date is already fully booked. Please choose another date.';

    public function run(): void
    {
        $columns = [
            'id', 'requester_id', 'request_date', 'trip_date', 'trip_end_date', 'trip_type',
            'departure_time', 'destination', 'purpose', 'estimated_return_time', 'passengers',
            'number_of_passengers', 'status', 'disapproval_reason',
            'approved_by', 'approved_date', 'created_at', 'updated_at',
        ];

        $requests = [
            // ---------- Approved ----------
            [1,  3,  '2026-08-28 09:15:00', '2026-09-03', '2026-09-03', 'inclusive', '08:00:00', self::MAIN, 'Faculty general assembly and department meeting', '16:00:00', 'Marife Aliaga and 3 faculty members', 4, 'approved', null, 1, '2026-08-31 10:00:00', '2026-08-28 09:15:00', '2026-08-31 10:00:00'],
            [2,  10, '2026-09-02 13:40:00', '2026-09-08', '2026-09-09', 'exclusive', '05:00:00', 'Office of the Congressman, House of Representatives, Quezon City, Metro Manila', 'Meeting with the congressman on the university budget and infrastructure projects', '20:00:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', null, 2, '2026-09-04 09:30:00', '2026-09-02 13:40:00', '2026-09-04 09:30:00'],
            [3,  6,  '2026-09-09 10:05:00', '2026-09-15', '2026-09-15', 'inclusive', '09:00:00', self::CAPITOL, 'Coordination meeting with provincial officials on extension programs', '15:00:00', 'Dennis Directo and 2 faculty members', 3, 'approved', null, 1, '2026-09-10 14:00:00', '2026-09-09 10:05:00', '2026-09-10 14:00:00'],
            [4,  8,  '2026-09-17 08:20:00', '2026-09-22', '2026-09-22', 'inclusive', '08:30:00', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with municipal officials on community partnership', '17:00:00', 'Gwen Kyle Gagasa and 5 faculty members', 6, 'approved', null, 2, '2026-09-18 11:00:00', '2026-09-17 08:20:00', '2026-09-18 11:00:00'],
            [5,  7,  '2026-10-06 11:10:00', '2026-10-12', '2026-10-12', 'inclusive', '07:30:00', self::CONGRESSMAN, 'Meeting with the congressman and staff on the scholarship program', '16:30:00', 'Mark John Viernes and 3 faculty members', 4, 'approved', null, 1, '2026-10-08 09:45:00', '2026-10-06 11:10:00', '2026-10-08 09:45:00'],
            [6,  9,  '2026-10-07 14:25:00', '2026-10-12', '2026-10-12', 'inclusive', '08:00:00', 'DepEd Schools Division Office, Bayombong, Nueva Vizcaya', 'Meeting with DepEd officials on the senior high school partnership', '15:00:00', 'Percival Labog and 2 faculty members', 3, 'approved', null, 2, '2026-10-08 10:15:00', '2026-10-07 14:25:00', '2026-10-08 10:15:00'],
            [7,  10, '2026-10-05 09:30:00', '2026-10-15', '2026-10-16', 'exclusive', '05:00:00', 'Department of Budget and Management, Manila', 'Meeting with DBM officials on the proposed university budget', '20:00:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', null, 1, '2026-10-07 10:00:00', '2026-10-05 09:30:00', '2026-10-07 10:00:00'],
            [8,  11, '2026-10-06 15:00:00', '2026-10-21', '2026-10-21', 'inclusive', '09:00:00', self::MAIN, 'Academic council meeting of all campus faculty', '16:00:00', 'Gerals Perez and 11 faculty members', 12, 'approved', null, 2, '2026-10-09 09:00:00', '2026-10-06 15:00:00', '2026-10-09 09:00:00'],
            [9,  12, '2026-10-08 10:40:00', '2026-10-22', '2026-10-22', 'inclusive', '08:00:00', self::CAPITOL, 'Presentation of the extension program to the provincial board', '17:00:00', 'Arnel Agustin and 3 faculty members', 4, 'approved', null, 1, '2026-10-09 16:20:00', '2026-10-08 10:40:00', '2026-10-09 16:20:00'],

            // ---------- Pending ----------
            [10, 4,  '2026-10-09 10:15:00', '2026-10-14', '2026-10-14', 'inclusive', '08:00:00', 'Municipal Hall, Bambang, Nueva Vizcaya', 'Meeting with the municipal planning office on the campus expansion project', '16:00:00', 'Vernyll Jan Asis and 2 faculty members', 3, 'pending', null, null, null, '2026-10-09 10:15:00', '2026-10-09 10:15:00'],
            [11, 5,  '2026-10-08 13:30:00', '2026-10-19', '2026-10-19', 'inclusive', '09:00:00', 'Provincial Health Office, Bayombong, Nueva Vizcaya', 'Meeting with the health office on the nursing students community program', '15:30:00', 'Krizsha Ellaine Salinas and 4 faculty members', 5, 'pending', null, null, null, '2026-10-08 13:30:00', '2026-10-08 13:30:00'],
            [12, 10, '2026-10-09 15:45:00', '2026-10-26', '2026-10-27', 'exclusive', '05:00:00', 'CHED Central Office, Quezon City, Metro Manila', 'Meeting with CHED officials on program accreditation', '19:00:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'pending', null, null, null, '2026-10-09 15:45:00', '2026-10-09 15:45:00'],
            [13, 3,  '2026-10-12 08:40:00', '2026-10-20', '2026-10-20', 'inclusive', '08:00:00', self::MAIN, 'Department heads meeting on the second semester schedule', '17:00:00', 'Marife Aliaga and 7 department heads', 8, 'pending', null, null, null, '2026-10-12 08:40:00', '2026-10-12 08:40:00'],
            [14, 8,  '2026-10-12 09:20:00', '2026-10-28', '2026-10-28', 'inclusive', '08:00:00', self::CAPITOL, 'Meeting with the provincial planning office on a research partnership', '16:00:00', 'Gwen Kyle Gagasa and 3 faculty members', 4, 'pending', null, null, null, '2026-10-12 09:20:00', '2026-10-12 09:20:00'],
            [15, 10, '2026-10-12 10:05:00', '2026-11-02', '2026-11-02', 'exclusive', '04:00:00', 'Ninoy Aquino International Airport (NAIA) Terminal 3, Pasay City, Metro Manila', 'Fetch the University President at the airport', '23:00:00', 'Wilfredo Dumale Jr.', 1, 'pending', null, null, null, '2026-10-12 10:05:00', '2026-10-12 10:05:00'],
            [16, 12, '2026-10-12 11:00:00', '2026-10-29', '2026-10-29', 'inclusive', '09:00:00', 'DTI Provincial Office, Bayombong, Nueva Vizcaya', 'Meeting with DTI officials on the entrepreneurship seminar', '15:00:00', 'Arnel Agustin and 2 faculty members', 3, 'pending', null, null, null, '2026-10-12 11:00:00', '2026-10-12 11:00:00'],
            [17, 9,  '2026-10-09 16:30:00', '2026-10-30', '2026-10-30', 'inclusive', '08:30:00', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with local officials on the barangay IT training program', '16:30:00', 'Percival Labog and 5 faculty members', 6, 'pending', null, null, null, '2026-10-09 16:30:00', '2026-10-09 16:30:00'],

            // ---------- Disapproved ----------
            [18, 7,  '2026-09-04 08:50:00', '2026-09-10', '2026-09-10', 'inclusive', '08:00:00', self::CAPITOL, 'Meeting with provincial officials on the IT skills program', '16:00:00', 'Mark John Viernes and 2 faculty members', 3, 'disapproved', self::MAINTENANCE, 1, null, '2026-09-04 08:50:00', '2026-09-07 10:00:00'],
            [19, 11, '2026-09-11 09:10:00', '2026-09-17', '2026-09-17', 'inclusive', '09:00:00', self::MAIN, 'Faculty planning meeting on the research agenda', '17:00:00', 'Gerals Perez and 9 faculty members', 10, 'disapproved', self::NO_DATE, 2, null, '2026-09-11 09:10:00', '2026-09-14 11:30:00'],
            [20, 10, '2026-09-16 14:00:00', '2026-09-24', '2026-09-25', 'exclusive', '05:00:00', 'DOST Central Office, Bicutan, Taguig City, Metro Manila', 'Meeting with DOST officials on research funding', '19:00:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'disapproved', self::NO_AVAILABLE, 1, null, '2026-09-16 14:00:00', '2026-09-18 09:00:00'],
            [21, 5,  '2026-09-30 10:30:00', '2026-10-06', '2026-10-06', 'inclusive', '08:00:00', 'Municipal Hall, Aritao, Nueva Vizcaya', 'Meeting with municipal officials on the community outreach program', '16:00:00', 'Krizsha Ellaine Salinas and 3 faculty members', 4, 'disapproved', self::MAINTENANCE, 2, null, '2026-09-30 10:30:00', '2026-10-02 09:30:00'],
            [22, 6,  '2026-10-02 11:15:00', '2026-10-09', '2026-10-09', 'inclusive', '07:30:00', self::CAPITOL, 'Meeting with the provincial agriculture office on the farm technology program', '15:30:00', 'Dennis Directo and 2 faculty members', 3, 'disapproved', self::NO_DATE, 1, null, '2026-10-02 11:15:00', '2026-10-05 10:00:00'],
            [23, 4,  '2026-10-07 09:00:00', '2026-10-13', '2026-10-13', 'inclusive', '09:00:00', self::CONGRESSMAN, 'Meeting with congressman staff on the scholarship program', '16:00:00', 'Vernyll Jan Asis and 3 faculty members', 4, 'disapproved', self::NO_DATE, 2, null, '2026-10-07 09:00:00', '2026-10-09 14:00:00'],
            [24, 12, '2026-10-05 13:20:00', '2026-10-21', '2026-10-21', 'inclusive', '08:00:00', self::MAIN, 'Faculty training workshop planning', '16:00:00', 'Arnel Agustin and 12 faculty members', 13, 'disapproved', 'No available vehicle for this group on the requested date. The only van that can carry 13 passengers is already booked.', 1, null, '2026-10-05 13:20:00', '2026-10-07 15:00:00'],
            [25, 3,  '2026-10-02 15:10:00', '2026-10-07', '2026-10-07', 'inclusive', '08:00:00', self::MAIN, 'Faculty meeting on curriculum review', '17:00:00', 'Marife Aliaga and 4 faculty members', 5, 'disapproved', self::MAINTENANCE, 2, null, '2026-10-02 15:10:00', '2026-10-05 11:00:00'],
        ];

        DB::table('vehicle_requests')->insert(
            array_map(fn (array $row) => array_combine($columns, $row), $requests)
        );
    }
}