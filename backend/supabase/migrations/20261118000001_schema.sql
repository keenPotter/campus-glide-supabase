-- CampusGlide schema for Supabase (Postgres)

create table public.profiles (
  id bigint generated always as identity primary key,
  auth_id uuid unique references auth.users (id) on delete cascade,
  email text not null unique,
  first_name varchar(100) not null,
  last_name varchar(100) not null,
  "position" varchar(255),
  phone_number varchar(20),
  role varchar(32) not null check (role in ('administrator', 'faculty', 'staff')),
  is_active boolean not null default true,
  deletion_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_role_active_idx on public.profiles (role, is_active);

create table public.vehicles (
  id bigint generated always as identity primary key,
  plate_number varchar(20) not null unique,
  vehicle_model varchar(100) not null,
  vehicle_type varchar(50) not null,
  color varchar(50),
  manufacture_year int,
  capacity int,
  mileage int not null default 0,
  status varchar(20) not null default 'available' check (status in ('available', 'in_use', 'maintenance', 'retired')),
  last_maintenance_date date,
  next_maintenance_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.drivers (
  id bigint generated always as identity primary key,
  first_name varchar(100) not null,
  last_name varchar(100) not null,
  license_number varchar(50) not null unique,
  license_expiry_date date not null,
  contact_number varchar(20),
  address varchar(255),
  assigned_vehicle_id bigint references public.vehicles (id) on delete set null,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vehicle_requests (
  id bigint generated always as identity primary key,
  requester_id bigint references public.profiles (id) on delete cascade,
  booking_source varchar(20) not null default 'online',
  requester_name varchar(255),
  requester_department varchar(255),
  requester_contact varchar(50),
  request_date timestamptz not null default now(),
  trip_date date not null,
  trip_end_date date not null,
  trip_type varchar(20) not null check (trip_type in ('inclusive', 'exclusive')),
  departure_time time not null,
  destination varchar(255) not null,
  purpose varchar(255) not null,
  estimated_return_time time not null,
  passengers varchar(255) not null,
  number_of_passengers int not null,
  status varchar(20) not null default 'pending' check (status in ('pending', 'approved', 'disapproved')),
  disapproval_reason varchar(500),
  edit_reason varchar(500),
  approved_by bigint references public.profiles (id) on delete set null,
  approved_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vehicle_requests_requester_idx on public.vehicle_requests (requester_id);
create index vehicle_requests_status_idx on public.vehicle_requests (status);
create index vehicle_requests_trip_date_idx on public.vehicle_requests (trip_date);

create table public.trips (
  id bigint generated always as identity primary key,
  vehicle_request_id bigint not null unique references public.vehicle_requests (id) on delete cascade,
  vehicle_id bigint not null references public.vehicles (id) on delete restrict,
  driver_id bigint not null references public.drivers (id) on delete restrict,
  trip_date date not null,
  departure_time time not null,
  estimated_return_time time,
  destination varchar(255) not null,
  purpose varchar(255) not null,
  trip_status varchar(20) not null default 'scheduled' check (trip_status in ('scheduled', 'in_progress', 'completed', 'cancelled')),
  actual_departure_time time,
  actual_return_time time,
  actual_mileage int,
  notes varchar(500),
  cancellation_reason varchar(500),
  cancelled_by bigint references public.profiles (id) on delete set null,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_trips_status_date on public.trips (trip_status, trip_date);

create table public.allocations (
  id bigint generated always as identity primary key,
  trip_id bigint not null unique references public.trips (id) on delete cascade,
  vehicle_id bigint not null references public.vehicles (id) on delete restrict,
  driver_id bigint not null references public.drivers (id) on delete restrict,
  allocated_by bigint not null references public.profiles (id) on delete restrict,
  allocation_date timestamptz not null,
  notes varchar(500),
  ruv_number varchar(12) unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reschedule_requests (
  id bigint generated always as identity primary key,
  trip_id bigint not null references public.trips (id) on delete cascade,
  requested_by bigint not null references public.profiles (id) on delete restrict,
  old_date date not null,
  new_date date not null,
  reason varchar(500) not null,
  status varchar(20) not null default 'pending' check (status in ('pending', 'approved', 'disapproved', 'cancelled')),
  handled_by bigint references public.profiles (id) on delete set null,
  admin_reason varchar(500),
  handled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_reschedule_status on public.reschedule_requests (status);

create table public.trip_request_shares (
  id bigint generated always as identity primary key,
  allocation_id bigint not null references public.allocations (id) on delete cascade,
  sender_id bigint not null references public.profiles (id) on delete cascade,
  recipient_id bigint not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index trip_request_shares_recipient_idx on public.trip_request_shares (recipient_id, created_at);

create table public.trip_views (
  id bigint generated always as identity primary key,
  user_id bigint not null references public.profiles (id) on delete cascade,
  trip_id bigint not null references public.trips (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  unique (user_id, trip_id)
);

create table public.vehicle_maintenance (
  id bigint generated always as identity primary key,
  vehicle_id bigint not null references public.vehicles (id) on delete cascade,
  maintenance_type varchar(20) not null check (maintenance_type in ('oil_change', 'repair', 'refueling', 'inspection', 'tire_service', 'other')),
  maintenance_category varchar(20) not null default 'preventive',
  description varchar(500),
  maintenance_date date not null,
  completion_date date,
  cost numeric(10, 2),
  next_due_date date,
  performed_by varchar(100),
  status varchar(20) not null default 'scheduled' check (status in ('scheduled', 'in_progress', 'completed', 'cancelled')),
  notes varchar(500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index idx_vehicle_date on public.vehicle_maintenance (vehicle_id, maintenance_date);
create index idx_maintenance_status_date on public.vehicle_maintenance (status, maintenance_date);

create table public.post_travel_reports (
  id bigint generated always as identity primary key,
  vehicle_id bigint not null references public.vehicles (id) on delete restrict,
  trip_id bigint references public.trips (id) on delete set null,
  travel_date_from date not null,
  travel_date_to date,
  places_of_travel varchar(500) not null,
  defects_observed text,
  defects_incurred text,
  remarks text,
  drivers varchar(500),
  arrival_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.fuel_usage_records (
  id bigint generated always as identity primary key,
  vehicle_id bigint not null references public.vehicles (id) on delete restrict,
  trip_id bigint references public.trips (id) on delete set null,
  record_date date not null,
  balance_in_tank numeric(10, 2) not null default 0,
  issuance_from_stock numeric(10, 2) not null default 0,
  fuel_purchased numeric(10, 2) not null default 0,
  fuel_used numeric(10, 2) not null default 0,
  end_trip_balance numeric(10, 2) not null default 0,
  riv_no varchar(100),
  riv_date date,
  or_no varchar(100),
  or_date date,
  lubricating_oil numeric(10, 2),
  diesel_water numeric(10, 2),
  gear_oil numeric(10, 2),
  brake_fluid numeric(10, 2),
  flushing_oil numeric(10, 2),
  grease numeric(10, 2),
  drivers varchar(500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.preventive_maintenance_checklists (
  id bigint generated always as identity primary key,
  vehicle_id bigint not null references public.vehicles (id) on delete restrict,
  pmuv_no varchar(100),
  inspection_date date not null,
  inspector_mechanic varchar(255),
  current_mileage bigint,
  last_oil_change date,
  last_air_filter_change date,
  last_cabin_filter_change date,
  last_oil_filter_change date,
  last_engine_tune_up date,
  other_parts text,
  remarks text,
  supervisor_recommendation text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
declare c text;
begin
  foreach c in array array[
    'belts_condition', 'hoses_condition', 'engine_condition', 'air_conditioning_condition',
    'wipers_condition', 'headlights_condition', 'driving_lights_condition', 'brake_lights_condition',
    'hazard_lights_condition', 'door_locks_condition', 'windows_windshield_condition', 'radio_condition',
    'tires_condition', 'liquid_levels_condition', 'other_parts_condition'
  ] loop
    execute format(
      'alter table public.preventive_maintenance_checklists add column %I varchar(20) check (%I in (''excellent'', ''good'', ''poor''))',
      c, c
    );
  end loop;
end $$;

create table public.audit_logs (
  id bigint generated always as identity primary key,
  user_id bigint not null references public.profiles (id) on delete restrict,
  action varchar(100) not null,
  target_table varchar(100),
  target_id varchar(100),
  ip_address varchar(45),
  created_at timestamptz not null default now()
);
create index audit_logs_created_idx on public.audit_logs (created_at, id);
create index audit_logs_action_idx on public.audit_logs (action, created_at);

-- Keeps updated_at current
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'vehicles', 'drivers', 'vehicle_requests', 'trips', 'allocations', 'reschedule_requests',
    'trip_request_shares', 'vehicle_maintenance', 'post_travel_reports', 'fuel_usage_records',
    'preventive_maintenance_checklists'
  ] loop
    execute format('create trigger touch_%1$s before update on public.%1$s for each row execute function public.touch_updated_at()', t);
  end loop;
end $$;

-- The audit log can only be added to, never changed or deleted
create or replace function public.audit_append_only() returns trigger language plpgsql as $$
begin
  raise exception 'Audit log records are append-only.';
end $$;

create trigger audit_logs_no_change before update or delete on public.audit_logs
  for each row execute function public.audit_append_only();

-- Tables are locked. All access goes through the api_* functions.
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;