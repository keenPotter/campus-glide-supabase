-- Demo data (replaces database/seeders/*). All passwords = "password".
-- IDs: users 1-2 administrators | 3-12 faculty (10 is the University President)
-- Requests 1-4 completed trips | 5-6 in progress (2026-10-12) | 7-8 scheduled | 9 needs allocation
--          10-17 pending | 18-25 disapproved

create or replace function pg_temp.uid(n int) returns uuid language sql as $$
    select ('00000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid
$$;

-- ---------------------------------------------------------------- users (auth + profile via trigger)
insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
)
select
    '00000000-0000-0000-0000-000000000000', pg_temp.uid(u.id), 'authenticated', 'authenticated',
    u.email, extensions.crypt('password', extensions.gen_salt('bf')), now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'role', u.role),
    jsonb_build_object('first_name', u.first_name, 'last_name', u.last_name,
                       'position', u.job, 'phone_number', u.phone, 'role', u.role),
    now(), now(), '', '', '', ''
from (values
    (1,  'tony.basatan@nvsu.edu.ph',    'Tony O.',         'Basatan',    'Chief, Motorpool',    '09171234501', 'administrator'),
    (2,  'jayson.pimentel@nvsu.edu.ph', 'Jayson R.',       'Pimentel',   'Unit Head-GSU',       '09171234502', 'administrator'),
    (3,  'marife.aliaga@nvsu.edu.ph',   'Marife',          'Aliaga',     'Professor',           '09201234503', 'faculty'),
    (4,  'vernyll.asis@nvsu.edu.ph',    'Vernyll Jan',     'Asis',       'Assistant Professor', '09201234504', 'faculty'),
    (5,  'krizsha.salinas@nvsu.edu.ph', 'Krizsha Ellaine', 'Salinas',    'Associate Professor', '09201234505', 'faculty'),
    (6,  'dennis.directo@nvsu.edu.ph',  'Dennis',          'Directo',    'Instructor',          '09201234506', 'faculty'),
    (7,  'mark.viernes@nvsu.edu.ph',    'Mark John',       'Viernes',    'Assistant Professor', '09201234507', 'faculty'),
    (8,  'gwen.gagasa@nvsu.edu.ph',     'Gwen Kyle',       'Gagasa',     'Instructor',          '09201234508', 'faculty'),
    (9,  'percival.labog@nvsu.edu.ph',  'Percival',        'Labog',      'Associate Professor', '09201234509', 'faculty'),
    (10, 'wilfredo.dumale@nvsu.edu.ph', 'Wilfredo',        'Dumale Jr.', 'University President','09201234510', 'faculty'),
    (11, 'gerals.perez@nvsu.edu.ph',    'Gerals',          'Perez',      'Professor',           '09201234511', 'faculty'),
    (12, 'arnel.agustin@nvsu.edu.ph',   'Arnel',           'Agustin',    'Instructor',          '09201234512', 'faculty')
) as u(id, email, first_name, last_name, job, phone, role);

insert into auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id,
       jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true),
       'email', id::text, now(), now(), now()
from auth.users
where email like '%@nvsu.edu.ph';

-- ---------------------------------------------------------------- vehicles
insert into public.vehicles (id, plate_number, vehicle_model, vehicle_type, color, manufacture_year, capacity, mileage,
                             status, last_maintenance_date, next_maintenance_date, is_active)
values
    (1, 'SAA 1234', 'Toyota Hiace Commuter', 'Van',         'White',       2019, 15, 84500,  'available',   '2026-08-10', '2027-02-10', true),
    (2, 'NBC 5521', 'Toyota Innova',         'MPV',         'Silver',      2020, 7,  61200,  'in_use',      '2026-07-15', '2027-01-15', true),
    (3, 'NAB 7712', 'Mitsubishi L300 FB',    'Utility Van', 'White',       2018, 3,  102300, 'available',   '2026-06-20', '2026-12-20', true),
    (4, 'NCD 3345', 'Toyota Coaster',        'Bus',         'White',       2017, 30, 156800, 'maintenance', '2026-04-18', '2026-10-18', true),
    (5, 'AEF 6098', 'Toyota Vios',           'Sedan',       'Black',       2021, 4,  38900,  'available',   '2026-09-05', '2027-03-05', true),
    (6, 'NGH 2271', 'Isuzu D-Max',           'Pickup',      'Gray',        2022, 5,  27400,  'in_use',      '2026-08-25', '2027-02-25', true),
    (7, 'ABK 4410', 'Nissan Urvan NV350',    'Van',         'Silver',      2016, 14, 189000, 'retired',     '2025-11-02', null,         false),
    (8, 'NLM 8830', 'Toyota Fortuner',       'SUV',         'Pearl White', 2023, 7,  15600,  'available',   '2026-09-12', '2027-03-12', true);

-- ---------------------------------------------------------------- drivers (standalone records, not users)
insert into public.drivers (id, first_name, last_name, license_number, license_expiry_date, contact_number,
                            address, assigned_vehicle_id, is_available)
values
    (1, 'Juan',    'Reyes',      'N02-19-012345', '2028-05-14', '09181234503', 'Brgy. Bonfal West, Bayombong, Nueva Vizcaya',        1, true),
    (2, 'Pedro',   'Bautista',   'N02-17-067890', '2027-11-30', '09181234504', 'Brgy. Magsaysay, Bayombong, Nueva Vizcaya',          2, false),
    (3, 'Carlos',  'Mendoza',    'N02-15-034567', '2026-11-15', '09181234505', 'Brgy. Don Mariano Marcos, Bayombong, Nueva Vizcaya', 4, true),
    (4, 'Ernesto', 'Villanueva', 'N02-20-045678', '2029-02-20', '09181234506', 'Brgy. Ipil-Cuneg, Bambang, Nueva Vizcaya',          6, false);

-- ---------------------------------------------------------------- vehicle requests
insert into public.vehicle_requests (
    id, requester_id, request_date, trip_date, trip_end_date, trip_type, departure_time, destination, purpose,
    estimated_return_time, passengers, number_of_passengers, status, disapproval_reason, approved_by, approved_date
) values
    -- Approved
    (1,  pg_temp.uid(3),  '2026-08-28 09:15:00+08', '2026-09-03', '2026-09-03', 'inclusive', '08:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Faculty general assembly and department meeting', '16:00', 'Marife Aliaga and 3 faculty members', 4, 'approved', null, pg_temp.uid(1), '2026-08-31 10:00:00+08'),
    (2,  pg_temp.uid(10), '2026-09-02 13:40:00+08', '2026-09-08', '2026-09-09', 'exclusive', '05:00', 'Office of the Congressman, House of Representatives, Quezon City, Metro Manila', 'Meeting with the congressman on the university budget and infrastructure projects', '20:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', null, pg_temp.uid(2), '2026-09-04 09:30:00+08'),
    (3,  pg_temp.uid(6),  '2026-09-09 10:05:00+08', '2026-09-15', '2026-09-15', 'inclusive', '09:00', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Coordination meeting with provincial officials on extension programs', '15:00', 'Dennis Directo and 2 faculty members', 3, 'approved', null, pg_temp.uid(1), '2026-09-10 14:00:00+08'),
    (4,  pg_temp.uid(8),  '2026-09-17 08:20:00+08', '2026-09-22', '2026-09-22', 'inclusive', '08:30', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with municipal officials on community partnership', '17:00', 'Gwen Kyle Gagasa and 5 faculty members', 6, 'approved', null, pg_temp.uid(2), '2026-09-18 11:00:00+08'),
    (5,  pg_temp.uid(7),  '2026-10-06 11:10:00+08', '2026-10-12', '2026-10-12', 'inclusive', '07:30', 'Office of the Congressman, Bayombong, Nueva Vizcaya', 'Meeting with the congressman and staff on the scholarship program', '16:30', 'Mark John Viernes and 3 faculty members', 4, 'approved', null, pg_temp.uid(1), '2026-10-08 09:45:00+08'),
    (6,  pg_temp.uid(9),  '2026-10-07 14:25:00+08', '2026-10-12', '2026-10-12', 'inclusive', '08:00', 'DepEd Schools Division Office, Bayombong, Nueva Vizcaya', 'Meeting with DepEd officials on the senior high school partnership', '15:00', 'Percival Labog and 2 faculty members', 3, 'approved', null, pg_temp.uid(2), '2026-10-08 10:15:00+08'),
    (7,  pg_temp.uid(10), '2026-10-05 09:30:00+08', '2026-10-15', '2026-10-16', 'exclusive', '05:00', 'Department of Budget and Management, Manila', 'Meeting with DBM officials on the proposed university budget', '20:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', null, pg_temp.uid(1), '2026-10-07 10:00:00+08'),
    (8,  pg_temp.uid(11), '2026-10-06 15:00:00+08', '2026-10-21', '2026-10-21', 'inclusive', '09:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Academic council meeting of all campus faculty', '16:00', 'Gerals Perez and 11 faculty members', 12, 'approved', null, pg_temp.uid(2), '2026-10-09 09:00:00+08'),
    (9,  pg_temp.uid(12), '2026-10-08 10:40:00+08', '2026-10-22', '2026-10-22', 'inclusive', '08:00', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Presentation of the extension program to the provincial board', '17:00', 'Arnel Agustin and 3 faculty members', 4, 'approved', null, pg_temp.uid(1), '2026-10-09 16:20:00+08'),
    -- Pending
    (10, pg_temp.uid(4),  '2026-10-09 10:15:00+08', '2026-10-14', '2026-10-14', 'inclusive', '08:00', 'Municipal Hall, Bambang, Nueva Vizcaya', 'Meeting with the municipal planning office on the campus expansion project', '16:00', 'Vernyll Jan Asis and 2 faculty members', 3, 'pending', null, null, null),
    (11, pg_temp.uid(5),  '2026-10-08 13:30:00+08', '2026-10-19', '2026-10-19', 'inclusive', '09:00', 'Provincial Health Office, Bayombong, Nueva Vizcaya', 'Meeting with the health office on the nursing students community program', '15:30', 'Krizsha Ellaine Salinas and 4 faculty members', 5, 'pending', null, null, null),
    (12, pg_temp.uid(10), '2026-10-09 15:45:00+08', '2026-10-26', '2026-10-27', 'exclusive', '05:00', 'CHED Central Office, Quezon City, Metro Manila', 'Meeting with CHED officials on program accreditation', '19:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'pending', null, null, null),
    (13, pg_temp.uid(3),  '2026-10-12 08:40:00+08', '2026-10-20', '2026-10-20', 'inclusive', '08:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Department heads meeting on the second semester schedule', '17:00', 'Marife Aliaga and 7 department heads', 8, 'pending', null, null, null),
    (14, pg_temp.uid(8),  '2026-10-12 09:20:00+08', '2026-10-28', '2026-10-28', 'inclusive', '08:00', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Meeting with the provincial planning office on a research partnership', '16:00', 'Gwen Kyle Gagasa and 3 faculty members', 4, 'pending', null, null, null),
    (15, pg_temp.uid(10), '2026-10-12 10:05:00+08', '2026-11-02', '2026-11-02', 'exclusive', '04:00', 'Ninoy Aquino International Airport (NAIA) Terminal 3, Pasay City, Metro Manila', 'Fetch the University President at the airport', '23:00', 'Wilfredo Dumale Jr.', 1, 'pending', null, null, null),
    (16, pg_temp.uid(12), '2026-10-12 11:00:00+08', '2026-10-29', '2026-10-29', 'inclusive', '09:00', 'DTI Provincial Office, Bayombong, Nueva Vizcaya', 'Meeting with DTI officials on the entrepreneurship seminar', '15:00', 'Arnel Agustin and 2 faculty members', 3, 'pending', null, null, null),
    (17, pg_temp.uid(9),  '2026-10-09 16:30:00+08', '2026-10-30', '2026-10-30', 'inclusive', '08:30', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with local officials on the barangay IT training program', '16:30', 'Percival Labog and 5 faculty members', 6, 'pending', null, null, null),
    -- Disapproved
    (18, pg_temp.uid(7),  '2026-09-04 08:50:00+08', '2026-09-10', '2026-09-10', 'inclusive', '08:00', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Meeting with provincial officials on the IT skills program', '16:00', 'Mark John Viernes and 2 faculty members', 3, 'disapproved', 'The vehicle needed for this trip is under maintenance on the requested date.', pg_temp.uid(1), null),
    (19, pg_temp.uid(11), '2026-09-11 09:10:00+08', '2026-09-17', '2026-09-17', 'inclusive', '09:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Faculty planning meeting on the research agenda', '17:00', 'Gerals Perez and 9 faculty members', 10, 'disapproved', 'The requested date is already fully booked. Please choose another date.', pg_temp.uid(2), null),
    (20, pg_temp.uid(10), '2026-09-16 14:00:00+08', '2026-09-24', '2026-09-25', 'exclusive', '05:00', 'DOST Central Office, Bicutan, Taguig City, Metro Manila', 'Meeting with DOST officials on research funding', '19:00', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'disapproved', 'No available driver or vehicle on the requested date.', pg_temp.uid(1), null),
    (21, pg_temp.uid(5),  '2026-09-30 10:30:00+08', '2026-10-06', '2026-10-06', 'inclusive', '08:00', 'Municipal Hall, Aritao, Nueva Vizcaya', 'Meeting with municipal officials on the community outreach program', '16:00', 'Krizsha Ellaine Salinas and 3 faculty members', 4, 'disapproved', 'The vehicle needed for this trip is under maintenance on the requested date.', pg_temp.uid(2), null),
    (22, pg_temp.uid(6),  '2026-10-02 11:15:00+08', '2026-10-09', '2026-10-09', 'inclusive', '07:30', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Meeting with the provincial agriculture office on the farm technology program', '15:30', 'Dennis Directo and 2 faculty members', 3, 'disapproved', 'The requested date is already fully booked. Please choose another date.', pg_temp.uid(1), null),
    (23, pg_temp.uid(4),  '2026-10-07 09:00:00+08', '2026-10-13', '2026-10-13', 'inclusive', '09:00', 'Office of the Congressman, Bayombong, Nueva Vizcaya', 'Meeting with congressman staff on the scholarship program', '16:00', 'Vernyll Jan Asis and 3 faculty members', 4, 'disapproved', 'The requested date is already fully booked. Please choose another date.', pg_temp.uid(2), null),
    (24, pg_temp.uid(12), '2026-10-05 13:20:00+08', '2026-10-21', '2026-10-21', 'inclusive', '08:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Faculty training workshop planning', '16:00', 'Arnel Agustin and 12 faculty members', 13, 'disapproved', 'No available vehicle for this group on the requested date. The only van that can carry 13 passengers is already booked.', pg_temp.uid(1), null),
    (25, pg_temp.uid(3),  '2026-10-02 15:10:00+08', '2026-10-07', '2026-10-07', 'inclusive', '08:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Faculty meeting on curriculum review', '17:00', 'Marife Aliaga and 4 faculty members', 5, 'disapproved', 'The vehicle needed for this trip is under maintenance on the requested date.', pg_temp.uid(2), null);

update public.vehicle_requests set created_at = request_date;

-- ---------------------------------------------------------------- trips (one per approved request 1-8)
insert into public.trips (id, vehicle_request_id, vehicle_id, driver_id, trip_date, departure_time, estimated_return_time,
                          destination, purpose, trip_status, actual_departure_time, actual_return_time, actual_mileage, notes)
values
    (1, 1, 2, 2, '2026-09-03', '08:00', '16:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Faculty general assembly and department meeting', 'completed', '08:05', '15:40', 45, null),
    (2, 2, 8, 4, '2026-09-08', '05:00', '20:00', 'Office of the Congressman, House of Representatives, Quezon City, Metro Manila', 'Meeting with the congressman on the university budget and infrastructure projects', 'completed', '05:10', '19:30', 690, 'Two-day trip, overnight stay in Quezon City.'),
    (3, 3, 5, 3, '2026-09-15', '09:00', '15:00', 'Provincial Capitol, Bayombong, Nueva Vizcaya', 'Coordination meeting with provincial officials on extension programs', 'completed', '09:05', '14:20', 24, null),
    (4, 4, 1, 1, '2026-09-22', '08:30', '17:00', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with municipal officials on community partnership', 'completed', '08:35', '16:40', 62, null),
    (5, 5, 2, 2, '2026-10-12', '07:30', '16:30', 'Office of the Congressman, Bayombong, Nueva Vizcaya', 'Meeting with the congressman and staff on the scholarship program', 'in_progress', '07:35', null, null, null),
    (6, 6, 6, 4, '2026-10-12', '08:00', '15:00', 'DepEd Schools Division Office, Bayombong, Nueva Vizcaya', 'Meeting with DepEd officials on the senior high school partnership', 'in_progress', '08:05', null, null, null),
    (7, 7, 8, 1, '2026-10-15', '05:00', '20:00', 'Department of Budget and Management, Manila', 'Meeting with DBM officials on the proposed university budget', 'scheduled', null, null, null, 'Two-day trip, overnight stay in Manila.'),
    (8, 8, 1, 3, '2026-10-21', '09:00', '16:00', 'NVSU Main Campus, Bayombong, Nueva Vizcaya', 'Academic council meeting of all campus faculty', 'scheduled', null, null, null, null);

insert into public.allocations (id, trip_id, vehicle_id, driver_id, allocated_by, allocation_date, notes)
values
    (1, 1, 2, 2, pg_temp.uid(1), '2026-08-31 11:00:00+08', null),
    (2, 2, 8, 4, pg_temp.uid(2), '2026-09-04 10:30:00+08', 'Overnight stay in Quezon City.'),
    (3, 3, 5, 3, pg_temp.uid(1), '2026-09-10 15:00:00+08', null),
    (4, 4, 1, 1, pg_temp.uid(2), '2026-09-18 12:00:00+08', null),
    (5, 5, 2, 2, pg_temp.uid(1), '2026-10-08 10:30:00+08', null),
    (6, 6, 6, 4, pg_temp.uid(2), '2026-10-08 11:00:00+08', null),
    (7, 7, 8, 1, pg_temp.uid(1), '2026-10-07 11:00:00+08', 'Overnight stay in Manila.'),
    (8, 8, 1, 3, pg_temp.uid(2), '2026-10-09 10:00:00+08', 'Passengers will gather at the main gate.');

-- ---------------------------------------------------------------- maintenance
-- The sync trigger is off while seeding, so the vehicle dates above stay exactly as written.
alter table public.vehicle_maintenance disable trigger trg_sync_vehicle_dates;

insert into public.vehicle_maintenance (id, vehicle_id, maintenance_type, description, maintenance_date, completion_date,
                                        cost, next_due_date, performed_by, status, notes)
values
    (1,  1, 'oil_change',   'Engine oil and oil filter replacement',      '2026-08-10', '2026-08-10', 3500.00,  '2027-02-10', 'Toyota Santiago Service Center', 'completed',   null),
    (2,  2, 'tire_service', 'Replaced four tires and wheel alignment',    '2026-07-15', '2026-07-15', 18400.00, '2027-07-15', 'Bayombong Tire Center',          'completed',   null),
    (3,  4, 'repair',       'Clutch assembly replacement',                '2026-09-25', null,         32000.00, null,         'Dela Cruz Auto Repair',          'in_progress', 'Waiting for delivery of clutch disc.'),
    (4,  3, 'inspection',   'Semi-annual general inspection',             '2026-06-20', '2026-06-20', 1200.00,  '2026-12-20', 'NVSU Motor Pool Mechanic',       'completed',   null),
    (5,  5, 'oil_change',   'Engine oil and filter replacement',          '2026-09-05', '2026-09-05', 2800.00,  '2027-03-05', 'Toyota Santiago Service Center', 'completed',   null),
    (6,  6, 'oil_change',   'Engine oil and filter replacement',          '2026-08-25', '2026-08-25', 5200.00,  '2027-02-25', 'Isuzu Cauayan Service Center',   'completed',   null),
    (7,  7, 'repair',       'Engine overhaul',                            '2026-03-10', '2026-03-10', 45000.00, null,         'Dela Cruz Auto Repair',          'completed',   'Unit recommended for retirement after overhaul.'),
    (8,  8, 'oil_change',   'First free service - oil and filter change', '2026-09-12', '2026-09-12', 4100.00,  '2027-03-12', 'Toyota Santiago Service Center', 'completed',   null),
    (9,  1, 'tire_service', 'Tire rotation and balancing',                '2026-10-20', null,         null,       null,         null,                             'scheduled',   null),
    (10, 3, 'other',        'Air conditioning servicing',                 '2026-05-02', null,         null,       null,         null,                             'cancelled',   'Rescheduled due to parts unavailability.'),
    (11, 6, 'inspection',   'Pre-long-trip safety inspection',            '2026-10-15', null,         null,       null,         'NVSU Motor Pool Mechanic',       'scheduled',   null);

alter table public.vehicle_maintenance enable trigger trg_sync_vehicle_dates;

-- ---------------------------------------------------------------- post travel reports (1-4 completed trips, 5 no trip)
insert into public.post_travel_reports (id, vehicle_id, trip_id, travel_date_from, travel_date_to, places_of_travel,
                                        defects_observed, defects_incurred, remarks, drivers, arrival_at)
values
    (1, 2, 1,    '2026-09-03', '2026-09-03', 'Bambang - Bayombong - Bambang',      null,                                null, 'Smooth trip. Vehicle in good running condition.',            'Pedro Bautista',     '2026-09-03 15:40:00+08'),
    (2, 8, 2,    '2026-09-08', '2026-09-09', 'Bayombong - Quezon City - Bayombong', 'Slight vibration at high speed.',   null, 'Overnight stay in Quezon City. Wheel alignment recommended.', 'Ernesto Villanueva', '2026-09-09 19:30:00+08'),
    (3, 5, 3,    '2026-09-15', '2026-09-15', 'Solano - Bayombong - Solano',        null,                                null, null,                                                         'Carlos Mendoza',     '2026-09-15 14:20:00+08'),
    (4, 1, 4,    '2026-09-22', '2026-09-22', 'Bambang - Solano - Bambang',         'Slight brake noise when stopping.', null, 'Brake inspection recommended before the next long trip.',    'Juan Reyes',         '2026-09-22 16:40:00+08'),
    (5, 3, null, '2026-09-28', null,         'Local errands within Bayombong',     null,                                null, null,                                                         'Carlos Mendoza',     '2026-09-28 15:30:00+08');

-- ---------------------------------------------------------------- fuel usage (1-4 completed trips, 5-6 no trip)
insert into public.fuel_usage_records (id, vehicle_id, trip_id, record_date, balance_in_tank, issuance_from_stock,
                                       fuel_purchased, fuel_used, end_trip_balance, riv_no, riv_date, or_no, or_date,
                                       lubricating_oil, drivers)
values
    (1, 2, 1,    '2026-09-03', 18.00, 20.00, 0.00,  5.00,  33.00, 'RIV-2026-0210', '2026-09-02', null,        null,         null, 'Pedro Bautista'),
    (2, 8, 2,    '2026-09-09', 45.00, 40.00, 30.00, 77.00, 38.00, 'RIV-2026-0214', '2026-09-07', 'OR-612045', '2026-09-08', 1.00, 'Ernesto Villanueva'),
    (3, 5, 3,    '2026-09-15', 20.00, 0.00,  0.00,  2.50,  17.50, null,            null,         null,        null,         null, 'Carlos Mendoza'),
    (4, 1, 4,    '2026-09-22', 22.00, 15.00, 0.00,  8.00,  29.00, 'RIV-2026-0226', '2026-09-21', null,        null,         null, 'Juan Reyes'),
    (5, 3, null, '2026-09-28', 10.00, 20.00, 0.00,  4.00,  26.00, 'RIV-2026-0233', '2026-09-27', null,        null,         null, 'Carlos Mendoza'),
    (6, 6, null, '2026-10-01', 12.00, 0.00,  40.00, 5.00,  47.00, null,            null,         'OR-613380', '2026-10-01', null, 'Ernesto Villanueva');

-- ---------------------------------------------------------------- preventive maintenance checklists
insert into public.preventive_maintenance_checklists (
    id, vehicle_id, pmuv_no, inspection_date, inspector_mechanic, current_mileage,
    last_oil_change, last_air_filter_change, last_cabin_filter_change, last_oil_filter_change, last_engine_tune_up,
    belts_condition, hoses_condition, engine_condition, air_conditioning_condition, wipers_condition,
    headlights_condition, driving_lights_condition, brake_lights_condition, hazard_lights_condition,
    door_locks_condition, windows_windshield_condition, radio_condition, tires_condition,
    liquid_levels_condition, other_parts_condition,
    other_parts, remarks, supervisor_recommendation
) values
    (1, 1, 'PMUV-2026-001', '2026-08-10', 'Rodel Quiambao', 84500, '2026-08-10', '2026-08-10', '2026-02-10', '2026-08-10', '2026-02-10',
     'good', 'good', 'excellent', 'good', 'good', 'excellent', 'good', 'excellent', 'excellent', 'good', 'good', 'good', 'good', 'excellent', 'good',
     null, 'Vehicle in good overall condition.', 'Continue regular maintenance schedule.'),
    (2, 2, 'PMUV-2026-002', '2026-07-15', 'Rodel Quiambao', 61200, '2026-05-15', '2026-05-15', '2026-01-15', '2026-05-15', '2026-01-15',
     'good', 'good', 'good', 'excellent', 'poor', 'good', 'good', 'good', 'good', 'excellent', 'good', 'excellent', 'excellent', 'good', 'good',
     null, 'Wipers worn out; tires newly replaced.', 'Replace wiper blades at next opportunity.'),
    (3, 3, 'PMUV-2026-003', '2026-06-20', 'Rodel Quiambao', 102300, '2026-03-20', '2025-12-20', null, '2026-03-20', '2025-12-20',
     'good', 'poor', 'good', 'poor', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'poor', 'good', 'good', 'good',
     'Radiator hose slightly cracked', 'Hoses and air conditioning need attention.', 'Replace radiator hose and schedule AC servicing.'),
    (4, 4, 'PMUV-2026-004', '2026-09-25', 'Efren Dela Cruz', 156800, '2026-04-18', '2026-04-18', '2025-10-18', '2026-04-18', '2025-10-18',
     'poor', 'good', 'poor', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'good', 'poor',
     'Clutch assembly worn', 'Unit undergoing clutch replacement. Belts and engine need follow-up check.', 'Do not release unit until repairs are completed and re-inspected.'),
    (5, 5, 'PMUV-2026-005', '2026-09-05', 'Rodel Quiambao', 38900, '2026-09-05', '2026-09-05', '2026-03-05', '2026-09-05', '2026-03-05',
     'excellent', 'excellent', 'excellent', 'excellent', 'good', 'excellent', 'excellent', 'excellent', 'excellent', 'excellent', 'excellent', 'good', 'excellent', 'excellent', 'excellent',
     null, 'Excellent condition.', 'No action needed.'),
    (6, 7, 'PMUV-2026-006', '2026-03-10', 'Efren Dela Cruz', 189000, '2025-11-02', '2025-06-02', null, '2025-11-02', '2025-06-02',
     'poor', 'poor', 'poor', 'poor', 'poor', 'poor', 'good', 'poor', 'good', 'poor', 'poor', 'poor', 'poor', 'poor', 'poor',
     'Chassis corrosion', 'Vehicle beyond economical repair.', 'Recommend retirement of unit.');

-- ---------------------------------------------------------------- identity sequences (ids were inserted explicitly)
do $$
declare
    t text;
begin
    foreach t in array array[
        'vehicles', 'drivers', 'vehicle_requests', 'trips', 'allocations', 'vehicle_maintenance',
        'post_travel_reports', 'fuel_usage_records', 'preventive_maintenance_checklists'
    ] loop
        execute format(
            'select setval(pg_get_serial_sequence(%L, ''id''), coalesce((select max(id) from public.%I), 1))',
            'public.' || t, t);
    end loop;
end $$;