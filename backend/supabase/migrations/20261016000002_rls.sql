-- Row Level Security. Replaces the `role:` middleware and the per-controller scoping.

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'administrator' and is_active
    )
$$;

create function public.is_faculty() returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'faculty' and is_active
    )
$$;

do $$
declare
    t text;
begin
    foreach t in array array[
        'profiles', 'vehicles', 'drivers', 'vehicle_requests', 'trips', 'allocations',
        'reschedule_requests', 'trip_request_shares', 'vehicle_maintenance',
        'post_travel_reports', 'fuel_usage_records', 'preventive_maintenance_checklists',
        'app_settings'
    ] loop
        execute format('alter table public.%I enable row level security', t);
    end loop;

    -- Administrator-only fleet forms (read, create, update; no delete, as before).
    foreach t in array array[
        'vehicle_maintenance', 'post_travel_reports', 'fuel_usage_records', 'preventive_maintenance_checklists'
    ] loop
        execute format('create policy admin_select on public.%I for select to authenticated using (public.is_admin())', t);
        execute format('create policy admin_insert on public.%I for insert to authenticated with check (public.is_admin())', t);
        execute format('create policy admin_update on public.%I for update to authenticated using (public.is_admin()) with check (public.is_admin())', t);
    end loop;
end $$;

-- profiles: everyone sees their own profile and the administrators (who approve and allocate).
create policy profiles_select on public.profiles for select to authenticated
    using (id = auth.uid() or public.is_admin() or role = 'administrator');
create policy profiles_update on public.profiles for update to authenticated
    using (public.is_admin()) with check (public.is_admin());

-- app_settings
create policy settings_select on public.app_settings for select to authenticated using (true);
create policy settings_write  on public.app_settings for all to authenticated
    using (public.is_admin()) with check (public.is_admin());

-- vehicle_requests: administrators see all, faculty only their own.
-- Faculty create requests directly. Everything else goes through the RPC functions.
create policy requests_select on public.vehicle_requests for select to authenticated
    using (public.is_admin() or requester_id = auth.uid());
create policy requests_insert on public.vehicle_requests for insert to authenticated
    with check (
        public.is_faculty()
        and requester_id = auth.uid()
        and status = 'pending'
        and approved_by is null and approved_date is null
        and disapproval_reason is null and edit_reason is null
    );

-- vehicles / drivers: administrators see everything. Faculty see only what is on their own trips.
create policy vehicles_select on public.vehicles for select to authenticated
    using (
        public.is_admin()
        or exists (
            select 1 from public.trips t
            join public.vehicle_requests r on r.id = t.vehicle_request_id
            where t.vehicle_id = vehicles.id and r.requester_id = auth.uid()
        )
    );
create policy vehicles_insert on public.vehicles for insert to authenticated with check (public.is_admin());
create policy vehicles_update on public.vehicles for update to authenticated
    using (public.is_admin()) with check (public.is_admin());

create policy drivers_select on public.drivers for select to authenticated
    using (
        public.is_admin()
        or exists (
            select 1 from public.trips t
            join public.vehicle_requests r on r.id = t.vehicle_request_id
            where t.driver_id = drivers.id and r.requester_id = auth.uid()
        )
    );
create policy drivers_insert on public.drivers for insert to authenticated with check (public.is_admin());
create policy drivers_update on public.drivers for update to authenticated
    using (public.is_admin()) with check (public.is_admin());

-- trips, allocations, reschedule_requests: read-only here. Writes go through the RPC functions.
create policy trips_select on public.trips for select to authenticated
    using (
        public.is_admin()
        or exists (select 1 from public.vehicle_requests r
                   where r.id = trips.vehicle_request_id and r.requester_id = auth.uid())
    );

create policy allocations_select on public.allocations for select to authenticated
    using (
        public.is_admin()
        or exists (select 1 from public.trips t
                   join public.vehicle_requests r on r.id = t.vehicle_request_id
                   where t.id = allocations.trip_id and r.requester_id = auth.uid())
    );

create policy reschedule_select on public.reschedule_requests for select to authenticated
    using (
        public.is_admin()
        or exists (select 1 from public.trips t
                   join public.vehicle_requests r on r.id = t.vehicle_request_id
                   where t.id = reschedule_requests.trip_id and r.requester_id = auth.uid())
    );

-- trip_request_shares: an administrator sends to another administrator and reads what was sent to them.
create policy shares_select on public.trip_request_shares for select to authenticated
    using (public.is_admin() and recipient_id = auth.uid());
create policy shares_insert on public.trip_request_shares for insert to authenticated
    with check (
        public.is_admin()
        and sender_id = auth.uid()
        and recipient_id <> auth.uid()
        and exists (select 1 from public.profiles p
                    where p.id = recipient_id and p.role = 'administrator' and p.is_active)
    );