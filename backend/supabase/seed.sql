-- Run with: supabase db reset
-- All passwords = "password"

create schema if not exists seed;

create or replace function seed.day(n integer) returns date
language sql stable as $$ select public.today_ph() + n $$;

create or replace function seed.at(n integer, t time) returns timestamptz
language sql stable as $$ select ((public.today_ph() + n) + t) at time zone 'Asia/Manila' $$;

create or replace function seed.uid(n integer) returns uuid
language sql immutable as $$ select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid $$;

-- ---------- Clear old data ----------
create temp table old_auth as select auth_user_id from public.profiles;

truncate table
  public.trip_request_shares, public.preventive_maintenance_checklists, public.fuel_usage_records,
  public.post_travel_reports, public.vehicle_maintenance, public.reschedule_requests,
  public.allocations, public.trips, public.vehicle_requests, public.drivers,
  public.vehicles, public.profiles
restart identity cascade;

delete from auth.users where id in (select auth_user_id from old_auth);
drop table old_auth;

-- ---------- Users ----------
-- IDs: 1-2 administrators | 3 staff | 4-8 faculty (4 is the University President)
--      9-10 test accounts | 11-13 extra administrators | 14-17 extra staff
--      18-22 extra faculty | 23-27 practice accounts for "Delete account"
create temp table seed_users (
  id integer, email text, first_name text, last_name text, pos text,
  phone text, role text, active boolean, del integer
);

insert into seed_users values
  (1,  'tony.basatan@nvsu.edu.ph',     'Tony',            'Basatan',      'Chief, Motorpool',          '09171234501', 'administrator', true,  null),
  (2,  'jayson.pimentel@nvsu.edu.ph',  'Jayson',          'Pimentel',     'Unit Head-GSU',             '09171234502', 'administrator', true,  null),
  (3,  'reonel.makil@nvsu.edu.ph',     'Reonel',          'Makil',        'Motorpool Staff',           '09171234503', 'staff',         true,  null),
  (4,  'wilfredo.dumale@nvsu.edu.ph',  'Wilfredo',        'Dumale Jr.',   'University President',      '09201234510', 'faculty',       true,  null),
  (5,  'marife.aliaga@nvsu.edu.ph',    'Marife',          'Aliaga',       'Professor',                 '09201234503', 'faculty',       true,  null),
  (6,  'krizsha.salinas@nvsu.edu.ph',  'Krizsha Ellaine', 'Salinas',      'Instructor',                '09201234505', 'faculty',       true,  null),
  (7,  'dennis.directo@nvsu.edu.ph',   'Dennis',          'Directo',      'Professor',                 '09201234506', 'faculty',       true,  null),
  (8,  'gwen.gagasa@nvsu.edu.ph',      'Gwen Kyle',       'Gagasa',       'Instructor',                '09201234508', 'faculty',       true,  null),
  (9,  'testuser1@nvsu.edu.ph',        'Test',            'User One',     'Instructor I',              '09201234521', 'faculty',       true,  null),
  (10, 'testuser2@nvsu.edu.ph',        'Test',            'User Two',     'Instructor I',              '09201234522', 'faculty',       false, -5),
  (11, 'admin.tester1@nvsu.edu.ph',    'Test',            'Admin One',    'Administrator (Tester)',    '09171234511', 'administrator', true,  null),
  (12, 'admin.tester2@nvsu.edu.ph',    'Test',            'Admin Two',    'Administrator (Tester)',    '09171234512', 'administrator', true,  null),
  (13, 'admin.tester3@nvsu.edu.ph',    'Test',            'Admin Three',  'Administrator (Tester)',    '09171234513', 'administrator', true,  null),
  (14, 'staff.tester1@nvsu.edu.ph',    'Test',            'Staff One',    'Motorpool Staff (Tester)',  '09171234514', 'staff',         true,  null),
  (15, 'staff.tester2@nvsu.edu.ph',    'Test',            'Staff Two',    'Motorpool Staff (Tester)',  '09171234515', 'staff',         true,  null),
  (16, 'staff.tester3@nvsu.edu.ph',    'Test',            'Staff Three',  'Motorpool Staff (Tester)',  '09171234516', 'staff',         true,  null),
  (17, 'staff.tester4@nvsu.edu.ph',    'Test',            'Staff Four',   'Motorpool Staff (Tester)',  '09171234517', 'staff',         true,  null),
  (18, 'faculty.tester1@nvsu.edu.ph',  'Test Faculty',    'One',          'Instructor I',              '09201234531', 'faculty',       true,  null),
  (19, 'faculty.tester2@nvsu.edu.ph',  'Test Faculty',    'Two',          'Instructor I',              '09201234532', 'faculty',       true,  null),
  (20, 'faculty.tester3@nvsu.edu.ph',  'Test Faculty',    'Three',        'Instructor I',              '09201234533', 'faculty',       true,  null),
  (21, 'faculty.tester4@nvsu.edu.ph',  'Test Faculty',    'Four',         'Instructor I',              '09201234534', 'faculty',       true,  null),
  (22, 'faculty.tester5@nvsu.edu.ph',  'Test Faculty',    'Five',         'Instructor I',              '09201234535', 'faculty',       true,  null),
  (23, 'delete.practice1@nvsu.edu.ph', 'Practice',        'Delete One',   'Instructor I',              '09201234541', 'faculty',       true,  null),
  (24, 'delete.practice2@nvsu.edu.ph', 'Practice',        'Delete Two',   'Instructor I',              '09201234542', 'faculty',       true,  null),
  (25, 'delete.practice3@nvsu.edu.ph', 'Practice',        'Delete Three', 'Instructor I',              '09201234543', 'faculty',       true,  null),
  (26, 'delete.practice4@nvsu.edu.ph', 'Practice',        'Delete Four',  'Instructor I',              '09201234544', 'faculty',       true,  null),
  (27, 'delete.practice5@nvsu.edu.ph', 'Practice',        'Delete Five',  'Instructor I',              '09201234545', 'faculty',       true,  null);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, banned_until,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000', seed.uid(id), 'authenticated', 'authenticated', email,
  extensions.crypt('password', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
  case when active then null else 'infinity'::timestamptz end,
  '', '', '', ''
from seed_users;

insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), seed.uid(id), seed.uid(id)::text, 'email',
  jsonb_build_object('sub', seed.uid(id)::text, 'email', email, 'email_verified', true),
  now(), now(), now()
from seed_users;

insert into public.profiles (
  id, auth_user_id, email, first_name, last_name, position, phone_number, role,
  is_active, deletion_requested_at, created_at, updated_at
)
select id, seed.uid(id), email, first_name, last_name, pos, phone, role, active,
  seed.at(del, '10:00:00'), seed.at(-55, '08:00:00'), seed.at(-55, '08:00:00')
from seed_users;

drop table seed_users;

-- ---------- Vehicles ----------
-- A vehicle with a scheduled or in-progress trip is "in_use". Vehicle 4 is under repair, 7 is retired.
insert into public.vehicles (
  id, plate_number, vehicle_model, vehicle_type, color, manufacture_year, capacity, mileage,
  status, last_maintenance_date, next_maintenance_date, is_active, created_at, updated_at
) values
  (1, 'SAA 1234', 'Toyota Hiace Commuter', 'Van',         'White',       2019, 15, 84500,  'in_use',      seed.day(-78),  seed.day(105), true,  seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (2, 'NBC 5521', 'Toyota Innova',         'MPV',         'Silver',      2020, 7,  61200,  'in_use',      seed.day(-103), seed.day(262), true,  seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (3, 'NAB 7712', 'Mitsubishi L300 FB',    'Utility Van', 'White',       2018, 3,  102300, 'in_use',      seed.day(-128), seed.day(-6),  true,  seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (4, 'NCD 3345', 'Toyota Coaster',        'Bus',         'White',       2017, 30, 156800, 'maintenance', seed.day(-191), seed.day(10),  true,  seed.at(-55, '08:00:00'), seed.at(-31, '09:00:00')),
  (5, 'AEF 6098', 'Toyota Vios',           'Sedan',       'Black',       2021, 4,  38900,  'in_use',      seed.day(-50),  seed.day(130), true,  seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (6, 'NGH 2271', 'Isuzu D-Max',           'Pickup',      'Gray',        2022, 5,  27400,  'in_use',      seed.day(-62),  seed.day(120), true,  seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (7, 'ABK 4410', 'Nissan Urvan NV350',    'Van',         'Silver',      2016, 14, 189000, 'retired',     seed.day(-345), null,          false, seed.at(-55, '08:00:00'), seed.at(-55, '08:00:00')),
  (8, 'NLM 8830', 'Toyota Fortuner',       'SUV',         'Pearl White', 2023, 7,  15600,  'in_use',      seed.day(-43),  seed.day(139), true,  seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00'));

-- ---------- Drivers ----------
insert into public.drivers (
  id, first_name, last_name, license_number, license_expiry_date, contact_number,
  address, assigned_vehicle_id, is_available, created_at, updated_at
) values
  (1, 'Juan',    'Reyes',      'N02-19-012345', seed.day(565),  '09181234503', 'Brgy. Bonfal West, Bayombong, Nueva Vizcaya',        8,    false, seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (2, 'Pedro',   'Bautista',   'N02-17-067890', seed.day(400),  '09181234504', 'Brgy. Magsaysay, Bayombong, Nueva Vizcaya',          2,    false, seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (3, 'Carlos',  'Mendoza',    'N02-15-034567', seed.day(20),   '09181234505', 'Brgy. Don Mariano Marcos, Bayombong, Nueva Vizcaya', 1,    false, seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (4, 'Ernesto', 'Villanueva', 'N02-20-045678', seed.day(850),  '09181234506', 'Brgy. Ipil-Cuneg, Bambang, Nueva Vizcaya',          6,    false, seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00')),
  (5, 'Rolando', 'Dizon',      'N02-18-078901', seed.day(700),  '09181234507', 'Brgy. Busilac, Bayombong, Nueva Vizcaya',            null, false, seed.at(-55, '08:00:00'), seed.at(-55, '08:00:00')),
  (6, 'Armando', 'Cabrera',    'N02-21-056789', seed.day(1100), '09181234508', 'Brgy. Bonfal East, Bayombong, Nueva Vizcaya',        8,    false, seed.at(-55, '08:00:00'), seed.at(-1, '07:10:00'));

do $seed$
declare
  main text := 'NVSU Main Campus, Bayombong, Nueva Vizcaya';
  capitol text := 'Provincial Capitol, Bayombong, Nueva Vizcaya';
  congressman text := 'Office of the Congressman, Bayombong, Nueva Vizcaya';
  maint text := 'The vehicle needed for this trip is under maintenance on the requested date.';
  no_available text := 'No available driver or vehicle on the requested date.';
  no_date text := 'The requested date is already fully booked. Please choose another date.';
  no_vehicle text := 'No available vehicle for this group on the requested date. The only van that can carry 13 passengers is already booked.';
  y integer := extract(year from public.today_ph())::int;
begin
  -- ---------- Vehicle requests ----------
  -- Approved, trip completed: 1, 2, 3, 4, 27 | in progress: 5, 6
  -- Approved, scheduled: 7, 8, 9, 13, 26, 28, 29, 30, 31, 32
  -- Pending: 10, 11, 12, 14, 15, 16, 17, 33, 34, 35 | Disapproved: 18 to 25
  insert into public.vehicle_requests (
    id, requester_id, request_date, trip_date, trip_end_date, trip_type, departure_time, destination,
    purpose, estimated_return_time, passengers, number_of_passengers, status, disapproval_reason,
    edit_reason, approved_by, approved_date, created_at, updated_at
  )
  select v.id, v.requester, sent.at_, seed.day(v.d1), seed.day(v.d2), v.trip_type, v.dep::time,
    v.destination, v.purpose, v.ret::time, v.passengers, v.cnt, v.status, v.reason, v.edit_reason,
    v.approver, case when v.status = 'approved' then dec.at_ end, sent.at_, coalesce(dec.at_, sent.at_)
  from (values
    (1,  5, -29, -24, -24, 'inclusive', '08:00:00', '16:00:00', main, 'Faculty general assembly and department meeting', 'Marife Aliaga and 3 faculty members', 4, 'approved', -27, 1, null, null),
    (2,  4, -25, -19, -18, 'exclusive', '05:00:00', '20:00:00', 'Office of the Congressman, House of Representatives, Quezon City, Metro Manila', 'Meeting with the congressman on the university budget and infrastructure projects', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', -23, 2, null, null),
    (3,  6, -17, -12, -12, 'inclusive', '09:00:00', '15:00:00', capitol, 'Coordination meeting with provincial officials on extension programs', 'Krizsha Ellaine Salinas and 2 faculty members', 3, 'approved', -15, 1, null, null),
    (4,  7, -13, -8,  -8,  'inclusive', '08:30:00', '17:00:00', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with municipal officials on community partnership', 'Dennis Directo and 5 faculty members', 6, 'approved', -11, 2, null, null),
    (5,  6, -6,  -1,  7,   'inclusive', '07:30:00', '16:30:00', 'Partner municipalities of Nueva Vizcaya', 'Week-long monitoring of students on off-campus practicum', 'Krizsha Ellaine Salinas and 3 faculty members', 4, 'approved', -4, 1, null, null),
    (6,  7, -5,  -1,  7,   'inclusive', '08:00:00', '15:00:00', 'Partner high schools in Bayombong, Solano and Bambang, Nueva Vizcaya', 'Week-long orientation and school visits for the senior high school partnership', 'Dennis Directo and 2 faculty members', 3, 'approved', -4, 2, null, null),
    (7,  4, -6,  10,  11,  'exclusive', '05:00:00', '20:00:00', 'Department of Budget and Management, Manila', 'Meeting with DBM officials on the proposed university budget', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', -4, 1, null, null),
    (8,  8, -7,  9,   9,   'inclusive', '09:00:00', '16:00:00', main, 'Academic council meeting of all campus faculty', 'Gwen Kyle Gagasa and 11 faculty members', 12, 'approved', -4, 2, null, null),
    (9,  7, -9,  12,  12,  'inclusive', '08:00:00', '17:00:00', capitol, 'Presentation of the extension program to the provincial board', 'Dennis Directo and 3 faculty members', 4, 'approved', -7, 1, null, null),
    (10, 5, -3,  2,   2,   'inclusive', '08:00:00', '16:00:00', 'Municipal Hall, Bambang, Nueva Vizcaya', 'Meeting with the municipal planning office on the campus expansion project', 'Marife Aliaga and 2 faculty members', 3, 'pending', null, null, null, null),
    (11, 6, -6,  5,   5,   'inclusive', '09:00:00', '15:30:00', 'Provincial Health Office, Bayombong, Nueva Vizcaya', 'Meeting with the health office on the nursing students community program', 'Krizsha Ellaine Salinas and 4 faculty members', 5, 'pending', -2, null, null, 'The provincial health office moved the meeting to a later date.'),
    (12, 4, -3,  20,  21,  'exclusive', '05:00:00', '19:00:00', 'CHED Central Office, Quezon City, Metro Manila', 'Meeting with CHED officials on program accreditation', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'pending', null, null, null, null),
    (13, 5, -9,  14,  14,  'inclusive', '08:00:00', '17:00:00', main, 'Department heads meeting on the second semester schedule', 'Marife Aliaga and 7 department heads', 8, 'approved', -7, 2, null, null),
    (14, 8, -2,  4,   4,   'inclusive', '08:00:00', '16:00:00', capitol, 'Meeting with the provincial planning office on a research partnership', 'Gwen Kyle Gagasa and 3 faculty members', 4, 'pending', null, null, null, null),
    (15, 4, -2,  24,  24,  'exclusive', '04:00:00', '23:00:00', 'Ninoy Aquino International Airport (NAIA) Terminal 3, Pasay City, Metro Manila', 'Fetch the University President at the airport', 'Wilfredo Dumale Jr.', 1, 'pending', null, null, null, null),
    (16, 7, -2,  3,   3,   'inclusive', '09:00:00', '15:00:00', 'DTI Provincial Office, Bayombong, Nueva Vizcaya', 'Meeting with DTI officials on the entrepreneurship seminar', 'Dennis Directo and 2 faculty members', 3, 'pending', null, null, null, null),
    (17, 6, -4,  9,   9,   'inclusive', '08:30:00', '16:30:00', 'Municipal Hall, Solano, Nueva Vizcaya', 'Meeting with local officials on the barangay IT training program', 'Krizsha Ellaine Salinas and 9 faculty members', 10, 'pending', null, null, null, null),
    (18, 8, -52, -46, -46, 'inclusive', '08:00:00', '16:00:00', capitol, 'Meeting with provincial officials on the IT skills program', 'Gwen Kyle Gagasa and 2 faculty members', 3, 'disapproved', -49, 1, maint, null),
    (19, 5, -45, -39, -39, 'inclusive', '09:00:00', '17:00:00', main, 'Faculty planning meeting on the research agenda', 'Marife Aliaga and 9 faculty members', 10, 'disapproved', -42, 2, no_date, null),
    (20, 4, -40, -32, -31, 'exclusive', '05:00:00', '19:00:00', 'DOST Central Office, Bicutan, Taguig City, Metro Manila', 'Meeting with DOST officials on research funding', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'disapproved', -38, 1, no_available, null),
    (21, 6, -34, -28, -28, 'inclusive', '08:00:00', '16:00:00', 'Municipal Hall, Aritao, Nueva Vizcaya', 'Meeting with municipal officials on the community outreach program', 'Krizsha Ellaine Salinas and 3 faculty members', 4, 'disapproved', -31, 2, maint, null),
    (22, 8, -30, -23, -23, 'inclusive', '07:30:00', '15:30:00', capitol, 'Meeting with the provincial agriculture office on the farm technology program', 'Gwen Kyle Gagasa and 2 faculty members', 3, 'disapproved', -27, 1, no_date, null),
    (23, 8, -22, -16, -16, 'inclusive', '09:00:00', '16:00:00', congressman, 'Meeting with congressman staff on the scholarship program', 'Gwen Kyle Gagasa and 3 faculty members', 4, 'disapproved', -19, 2, no_date, null),
    (24, 7, -20, -13, -13, 'inclusive', '08:00:00', '16:00:00', main, 'Faculty training workshop planning', 'Dennis Directo and 12 faculty members', 13, 'disapproved', -17, 1, no_vehicle, null),
    (25, 5, -15, -9,  -9,  'inclusive', '08:00:00', '17:00:00', main, 'Faculty meeting on curriculum review', 'Marife Aliaga and 4 faculty members', 5, 'disapproved', -12, 2, maint, null),
    (26, 4, -5,  0,   7,   'exclusive', '05:00:00', '17:00:00', 'Partner universities in Metro Manila and Baguio City', 'Week-long benchmarking visit to partner universities on academic programs', 'Wilfredo Dumale Jr. and 2 university officials', 3, 'approved', -3, 1, null, null),
    (27, 8, -10, -5,  -5,  'inclusive', '08:00:00', '15:00:00', congressman, 'Meeting with the congressman and staff on the scholarship program', 'Gwen Kyle Gagasa and 3 faculty members', 4, 'approved', -8, 2, null, null),
    (28, 5, -6,  15,  15,  'inclusive', '09:00:00', '16:00:00', 'DepEd Schools Division Office, Bayombong, Nueva Vizcaya', 'Meeting with DepEd officials on the senior high school partnership', 'Marife Aliaga and 2 faculty members', 3, 'approved', -3, 1, null, null),
    (29, 6, -6,  16,  16,  'inclusive', '08:00:00', '17:00:00', 'Municipal Hall, Bayombong, Nueva Vizcaya', 'Meeting with the municipal mayor on the community extension agreement', 'Krizsha Ellaine Salinas and 3 faculty members', 4, 'approved', -3, 2, null, null),
    (30, 7, -5,  17,  17,  'inclusive', '08:00:00', '16:00:00', 'Nueva Vizcaya Provincial Hospital, Bayombong, Nueva Vizcaya', 'Coordination with hospital officials on nursing student affiliation', 'Dennis Directo and 4 faculty members', 5, 'approved', -2, 1, null, null),
    (31, 6, -4,  18,  18,  'inclusive', '09:00:00', '15:00:00', 'Provincial Agriculture Office, Bayombong, Nueva Vizcaya', 'Meeting on the farm technology demonstration project', 'Krizsha Ellaine Salinas and 2 faculty members', 3, 'approved', -2, 2, null, null),
    (32, 8, -4,  19,  19,  'inclusive', '08:30:00', '16:30:00', main, 'Research colloquium and faculty presentation', 'Gwen Kyle Gagasa and 9 faculty members', 10, 'approved', -1, 1, null, null),
    (33, 8, -1,  6,   6,   'inclusive', '08:00:00', '16:00:00', 'Municipal Hall, Dupax del Sur, Nueva Vizcaya', 'Meeting with municipal officials on the youth livelihood training', 'Gwen Kyle Gagasa and 3 faculty members', 4, 'pending', null, null, null, null),
    (34, 5, -1,  8,   8,   'inclusive', '09:00:00', '15:00:00', capitol, 'Courtesy call and presentation of the new research center', 'Marife Aliaga and 2 faculty members', 3, 'pending', null, null, null, null),
    (35, 7, -1,  13,  13,  'inclusive', '08:00:00', '16:00:00', 'Municipal Hall, Kayapa, Nueva Vizcaya', 'Meeting on the community-based tourism study', 'Dennis Directo and 2 faculty members', 3, 'pending', null, null, null, null)
  ) as v(id, requester, sent_day, d1, d2, trip_type, dep, ret, destination, purpose, passengers, cnt, status, decided, approver, reason, edit_reason)
  cross join lateral (
    select seed.at(v.sent_day, format('%s:%s:00', lpad((8 + v.id % 8)::text, 2, '0'), lpad(((v.id * 7) % 60)::text, 2, '0'))::time) as at_
  ) sent
  left join lateral (
    select seed.at(v.decided, '10:00:00') as at_ where v.decided is not null
  ) dec on true;

  -- ---------- Trips (one for each approved request) ----------
  insert into public.trips (
    id, vehicle_request_id, vehicle_id, driver_id, trip_date, departure_time, estimated_return_time,
    destination, purpose, trip_status, actual_departure_time, actual_return_time, actual_mileage,
    notes, created_at, updated_at
  )
  select a.id, a.req, a.vehicle, a.driver, r.trip_date, r.departure_time, r.estimated_return_time,
    r.destination, r.purpose, a.status, a.dep::time, a.ret::time, a.mileage, a.notes, r.approved_date,
    case a.status
      when 'completed'   then (r.trip_end_date + a.ret::time) at time zone 'Asia/Manila'
      when 'in_progress' then (r.trip_date + a.dep::time) at time zone 'Asia/Manila'
      else r.approved_date
    end
  from (values
    (1,  1,  2, 2, 'completed',   '08:05:00', '15:40:00', 45,   null),
    (2,  2,  8, 4, 'completed',   '05:10:00', '19:30:00', 690,  'Two-day trip, overnight stay in Quezon City.'),
    (3,  3,  5, 3, 'completed',   '09:05:00', '14:20:00', 24,   null),
    (4,  4,  1, 1, 'completed',   '08:35:00', '16:40:00', 62,   null),
    (5,  27, 5, 6, 'completed',   '08:05:00', '14:30:00', 31,   null),
    (6,  5,  2, 2, 'in_progress', '07:35:00', null,       null, 'Week-long monitoring. The vehicle goes out every day.'),
    (7,  6,  6, 4, 'in_progress', '08:05:00', null,       null, null),
    (8,  26, 8, 6, 'scheduled',   null,       null,       null, 'Week-long trip. Overnight stays in Metro Manila and Baguio City.'),
    (9,  7,  8, 1, 'scheduled',   null,       null,       null, 'Two-day trip, overnight stay in Manila.'),
    (10, 8,  1, 3, 'scheduled',   null,       null,       null, null),
    (11, 9,  5, 3, 'scheduled',   null,       null,       null, null),
    (12, 13, 1, 1, 'scheduled',   null,       null,       null, null),
    (13, 28, 3, 2, 'scheduled',   null,       null,       null, null),
    (14, 29, 5, 3, 'scheduled',   null,       null,       null, null),
    (15, 30, 1, 4, 'scheduled',   null,       null,       null, null),
    (16, 31, 2, 6, 'scheduled',   null,       null,       null, null),
    (17, 32, 1, 1, 'scheduled',   null,       null,       null, null)
  ) as a(id, req, vehicle, driver, status, dep, ret, mileage, notes)
  join public.vehicle_requests r on r.id = a.req;

  -- ---------- Allocations ----------
  insert into public.allocations (
    id, trip_id, vehicle_id, driver_id, allocated_by, allocation_date, notes, ruv_number, created_at, updated_at
  )
  select t.id, t.id, t.vehicle_id, t.driver_id, r.approved_by, r.approved_date,
    case t.vehicle_request_id
      when 2 then 'Overnight stay in Quezon City.'
      when 7 then 'Overnight stay in Manila.'
      when 8 then 'Passengers will gather at the main gate.'
    end,
    case when t.trip_status in ('completed', 'in_progress') then
      format('%s-%s', y, lpad((count(*) filter (where t.trip_status in ('completed', 'in_progress')) over (order by t.id))::text, 4, '0'))
    end,
    r.approved_date, r.approved_date
  from public.trips t
  join public.vehicle_requests r on r.id = t.vehicle_request_id
  order by t.id;

  -- ---------- Date change requests: 4 pending, 1 approved, 1 disapproved ----------
  insert into public.reschedule_requests (
    id, trip_id, requested_by, old_date, new_date, reason, status, handled_by, admin_reason,
    handled_at, created_at, updated_at
  )
  select v.id, t.id, v.by_, seed.day(v.old_day), seed.day(v.new_day), v.reason, v.status, v.handler,
    v.note, h.at_, s.at_, coalesce(h.at_, s.at_)
  from (values
    (1, 8,  8, 9,  11, 'The academic council meeting was moved to a later date.',       'pending',     null, null, -1, null),
    (2, 28, 5, 15, 17, 'The DepEd officials asked to move the meeting by two days.',     'pending',     null, null, -1, null),
    (3, 29, 6, 16, 19, 'The municipal mayor asked to move the meeting to a later date.', 'pending',     null, null, -1, null),
    (4, 30, 7, 17, 22, 'The hospital administration moved the coordination meeting.',    'pending',     null, null, -1, null),
    (5, 9,  7, 11, 12, 'The provincial board moved the presentation to the next day.',   'approved',    1, 'Approved. The vehicle and driver are free on the new date.', -4, -3),
    (6, 13, 5, 14, 15, 'The department heads asked to move the meeting by one day.',     'disapproved', 2, 'The motorpool cannot move this trip. Please keep the original date.', -3, -2)
  ) as v(id, req, by_, old_day, new_day, reason, status, handler, note, sent_day, handled_day)
  join public.trips t on t.vehicle_request_id = v.req
  cross join lateral (select seed.at(v.sent_day, '09:00:00') as at_) s
  left join lateral (select seed.at(v.handled_day, '14:00:00') as at_ where v.handled_day is not null) h on true;

  -- ---------- Trip requests sent between administrators ----------
  insert into public.trip_request_shares (id, allocation_id, sender_id, recipient_id, created_at, updated_at)
  select v.id, a.id, v.sender, v.recipient, seed.at(-1, '11:00:00'), seed.at(-1, '11:00:00')
  from (values (1, 8, 1, 2), (2, 7, 2, 1)) as v(id, req, sender, recipient)
  join public.trips t on t.vehicle_request_id = v.req
  join public.allocations a on a.trip_id = t.id;

  -- ---------- Maintenance ----------
  -- Statuses: in progress (3), upcoming (1, 2, 5, 6, 8, 9, 11 to 16), overdue (4), cancelled (10), completed (7).
  -- The trigger is turned off here so the vehicle dates above stay as written.
  alter table public.vehicle_maintenance disable trigger trg_vehicle_maintenance_sync;

  insert into public.vehicle_maintenance (
    id, vehicle_id, maintenance_type, description, maintenance_date, completion_date, cost,
    next_due_date, performed_by, status, notes, created_at, updated_at
  )
  select v.id, v.vehicle, v.type, v.descr, seed.day(v.d), seed.day(v.done), v.cost, seed.day(v.next_due),
    v.by_, v.status, v.notes, seed.at(least(v.d - 4, -1), '09:00:00'),
    seed.at(coalesce(v.upd, v.done, least(v.d - 4, -1)), '15:00:00')
  from (values
    (1,  1, 'oil_change',   'Engine oil and oil filter replacement',      -78,  -78,  3500.00,  105,  'Toyota Santiago Service Center', 'completed',   null, null),
    (2,  2, 'tire_service', 'Replaced four tires and wheel alignment',    -103, -103, 18400.00, 262,  'Bayombong Tire Center',          'completed',   null, null),
    (3,  4, 'repair',       'Clutch assembly replacement',                -31,  null, 32000.00, null, 'Dela Cruz Auto Repair',          'in_progress', 'Waiting for delivery of clutch disc.', -3),
    (4,  3, 'inspection',   'Semi-annual general inspection',             -128, -128, 1200.00,  -6,   'NVSU Motor Pool Mechanic',       'completed',   null, null),
    (5,  5, 'oil_change',   'Engine oil and filter replacement',          -50,  -50,  2800.00,  130,  'Toyota Santiago Service Center', 'completed',   null, null),
    (6,  6, 'oil_change',   'Engine oil and filter replacement',          -62,  -62,  5200.00,  120,  'Isuzu Cauayan Service Center',   'completed',   null, null),
    (7,  7, 'repair',       'Engine overhaul',                            -230, -230, 45000.00, null, 'Dela Cruz Auto Repair',          'completed',   'Unit recommended for retirement after overhaul.', null),
    (8,  8, 'oil_change',   'First free service - oil and filter change', -43,  -43,  4100.00,  139,  'Toyota Santiago Service Center', 'completed',   null, null),
    (9,  1, 'tire_service', 'Tire rotation and balancing',                14,   null, null,     null, null,                             'scheduled',   null, null),
    (10, 3, 'other',        'Air conditioning servicing',                 -175, null, null,     null, null,                             'cancelled',   'Rescheduled due to parts unavailability.', -175),
    (11, 6, 'inspection',   'Pre-long-trip safety inspection',            9,    null, null,     null, 'NVSU Motor Pool Mechanic',       'scheduled',   null, null),
    (12, 4, 'inspection',   'Post-repair safety inspection',              12,   null, null,     null, 'NVSU Motor Pool Mechanic',       'scheduled',   null, null),
    (13, 4, 'tire_service', 'Tire replacement and wheel alignment',       16,   null, null,     null, 'Bayombong Tire Center',          'scheduled',   null, null),
    (14, 4, 'oil_change',   'Engine oil and filter replacement',          21,   null, null,     null, 'Toyota Santiago Service Center', 'scheduled',   null, null),
    (15, 4, 'other',        'Air conditioning servicing',                 27,   null, null,     null, 'Dela Cruz Auto Repair',          'scheduled',   null, null),
    (16, 4, 'inspection',   'Monthly safety inspection',                  33,   null, null,     null, 'NVSU Motor Pool Mechanic',       'scheduled',   null, null)
  ) as v(id, vehicle, type, descr, d, done, cost, next_due, by_, status, notes, upd);

  alter table public.vehicle_maintenance enable trigger trg_vehicle_maintenance_sync;

  -- ---------- Post-travel reports (1-5 belong to completed trips, 6 has no trip) ----------
  insert into public.post_travel_reports (
    id, vehicle_id, trip_id, travel_date_from, travel_date_to, places_of_travel, defects_observed,
    defects_incurred, remarks, drivers, arrival_at, created_at, updated_at
  )
  select v.id, v.vehicle, t.id, seed.day(v.d1), seed.day(v.d2), v.places, v.observed, v.incurred,
    v.remarks, v.drivers,
    seed.at(coalesce(v.d2, v.d1), v.arr::time),
    seed.at(coalesce(v.d2, v.d1), v.arr::time + interval '20 minutes'),
    seed.at(coalesce(v.d2, v.d1), v.arr::time + interval '20 minutes')
  from (values
    (1, 2, 1,    -24, -24,  'Bambang - Bayombong - Bambang',       null,                                null, 'Smooth trip. Vehicle in good running condition.',            'Pedro Bautista',     '15:40:00'),
    (2, 8, 2,    -19, -18,  'Bayombong - Quezon City - Bayombong', 'Slight vibration at high speed.',   null, 'Overnight stay in Quezon City. Wheel alignment recommended.', 'Ernesto Villanueva', '19:30:00'),
    (3, 5, 3,    -12, -12,  'Solano - Bayombong - Solano',         null,                                null, null,                                                         'Carlos Mendoza',     '14:20:00'),
    (4, 1, 4,    -8,  -8,   'Bambang - Solano - Bambang',          'Slight brake noise when stopping.', null, 'Brake inspection recommended before the next long trip.',    'Juan Reyes',         '16:40:00'),
    (5, 5, 27,   -5,  -5,   'Bayombong - Congressman''s office - Bayombong', null,                      null, null,                                                         'Armando Cabrera',    '14:30:00'),
    (6, 3, null, -14, null, 'Local errands within Bayombong',      null,                                null, null,                                                         'Carlos Mendoza',     '15:30:00')
  ) as v(id, vehicle, req, d1, d2, places, observed, incurred, remarks, drivers, arr)
  left join public.trips t on t.vehicle_request_id = v.req;

  -- ---------- Fuel usage (end_trip_balance is calculated, so it is always correct) ----------
  insert into public.fuel_usage_records (
    id, vehicle_id, trip_id, record_date, balance_in_tank, issuance_from_stock, fuel_purchased,
    fuel_used, end_trip_balance, riv_no, riv_date, or_no, or_date, lubricating_oil, drivers,
    created_at, updated_at
  )
  select v.id, v.vehicle, t.id, seed.day(v.d), v.bal, v.iss, v.pur, v.used,
    round(v.bal + v.iss + v.pur - v.used, 2), v.riv, seed.day(v.riv_d), v.or_no, seed.day(v.or_d),
    v.lub, v.drivers, seed.at(v.d, '16:00:00'), seed.at(v.d, '16:00:00')
  from (values
    (1, 2, 1,    -24, 18.00, 20.00, 0.00,  5.00,  'RIV-' || y || '-210', -25, null,        null, null, 'Pedro Bautista'),
    (2, 8, 2,    -18, 45.00, 40.00, 30.00, 77.00, 'RIV-' || y || '-214', -21, 'OR-612045', -20,  1.00, 'Ernesto Villanueva'),
    (3, 5, 3,    -12, 20.00, 0.00,  0.00,  2.50,  null,                  null, null,        null, null, 'Carlos Mendoza'),
    (4, 1, 4,    -8,  22.00, 15.00, 0.00,  8.00,  'RIV-' || y || '-226', -9,  null,        null, null, 'Juan Reyes'),
    (5, 5, 27,   -5,  15.00, 0.00,  20.00, 6.00,  null,                  null, 'OR-613402', -5,   null, 'Armando Cabrera'),
    (6, 3, null, -14, 10.00, 20.00, 0.00,  4.00,  'RIV-' || y || '-233', -15, null,        null, null, 'Carlos Mendoza'),
    (7, 6, null, -11, 12.00, 0.00,  40.00, 5.00,  null,                  null, 'OR-613380', -11,  null, 'Ernesto Villanueva')
  ) as v(id, vehicle, req, d, bal, iss, pur, used, riv, riv_d, or_no, or_d, lub, drivers)
  left join public.trips t on t.vehicle_request_id = v.req;

  -- ---------- Preventive maintenance checklists ----------
  -- s1 to s5: days before or after the inspection for oil change, air filter, cabin filter,
  -- oil filter and engine tune-up (empty = never done).
  insert into public.preventive_maintenance_checklists (
    id, vehicle_id, pmuv_no, inspection_date, inspector_mechanic, current_mileage,
    last_oil_change, last_air_filter_change, last_cabin_filter_change, last_oil_filter_change, last_engine_tune_up,
    belts_condition, hoses_condition, engine_condition, air_conditioning_condition, wipers_condition,
    headlights_condition, driving_lights_condition, brake_lights_condition, hazard_lights_condition,
    door_locks_condition, windows_windshield_condition, radio_condition, tires_condition,
    liquid_levels_condition, other_parts_condition, other_parts, remarks, supervisor_recommendation,
    created_at, updated_at
  )
  select v.id, v.vehicle,
    format('PMUV-%s-%s', extract(year from seed.day(v.dy))::int, lpad(v.id::text, 3, '0')),
    seed.day(v.dy), v.inspector, v.mileage,
    seed.day(v.dy + v.s1), seed.day(v.dy + v.s2), seed.day(v.dy + v.s3), seed.day(v.dy + v.s4), seed.day(v.dy + v.s5),
    v.r[1], v.r[2], v.r[3], v.r[4], v.r[5], v.r[6], v.r[7], v.r[8], v.r[9], v.r[10], v.r[11], v.r[12], v.r[13], v.r[14], v.r[15],
    v.other, v.remarks, v.rec, seed.at(v.dy, '15:30:00'), seed.at(v.dy, '15:30:00')
  from (values
    (1, 1, -78,  'Rodel Quiambao', 84500,  0,   0,    -180, 0,   -180,
      array['good','good','excellent','good','good','excellent','good','excellent','excellent','good','good','good','good','excellent','good'],
      null, 'Vehicle in good overall condition.', 'Continue regular maintenance schedule.'),
    (2, 2, -103, 'Rodel Quiambao', 61200,  -61, -61,  -181, -61, -181,
      array['good','good','good','excellent','poor','good','good','good','good','excellent','good','excellent','excellent','good','good'],
      null, 'Wipers worn out; tires newly replaced.', 'Replace wiper blades at next opportunity.'),
    (3, 3, -128, 'Rodel Quiambao', 102300, -92, -182, null, -92, -182,
      array['good','poor','good','poor','good','good','good','good','good','good','good','poor','good','good','good'],
      'Radiator hose slightly cracked', 'Hoses and air conditioning need attention.', 'Replace radiator hose and schedule AC servicing.'),
    (4, 4, -31,  'Efren Dela Cruz', 156800, -160, -160, -342, -160, -342,
      array['poor','good','poor','good','good','good','good','good','good','good','good','good','good','good','poor'],
      'Clutch assembly worn', 'Unit undergoing clutch replacement. Belts and engine need follow-up check.', 'Do not release unit until repairs are completed and re-inspected.'),
    (5, 5, -50,  'Rodel Quiambao', 38900,  0,   0,    -184, 0,   -184,
      array['excellent','excellent','excellent','excellent','good','excellent','excellent','excellent','excellent','excellent','excellent','good','excellent','excellent','excellent'],
      null, 'Excellent condition.', 'No action needed.'),
    (6, 7, -230, 'Efren Dela Cruz', 189000, -128, -281, null, -128, -281,
      array['poor','poor','poor','poor','poor','poor','good','poor','good','poor','poor','poor','poor','poor','poor'],
      'Chassis corrosion', 'Vehicle beyond economical repair.', 'Recommend retirement of unit.')
  ) as v(id, vehicle, dy, inspector, mileage, s1, s2, s3, s4, s5, r, other, remarks, rec);
end $seed$;

-- ---------- Move the ID counters past the seeded rows ----------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'vehicles', 'drivers', 'vehicle_requests', 'trips', 'allocations',
    'reschedule_requests', 'trip_request_shares', 'vehicle_maintenance',
    'post_travel_reports', 'fuel_usage_records', 'preventive_maintenance_checklists'
  ] loop
    execute format(
      'select setval(pg_get_serial_sequence(%L, ''id''), coalesce((select max(id) from public.%I), 1), (select count(*) > 0 from public.%I))',
      'public.' || t, t, t
    );
  end loop;
end $$;