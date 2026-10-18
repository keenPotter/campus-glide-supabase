-- Staff access to the allocation tools, RUV number, vehicle status and admin list.
-- Matches the routes that Laravel opens to 'role:administrator,staff'.
-- create_allocation, update_allocation, update_vehicle_request_status and get_checklist_print
-- stay administrator only, as in Laravel (the Form Requests block staff).

-- ---------------------------------------------------------------- RUV number
alter table public.allocations
    add column if not exists ruv_number text unique check (char_length(ruv_number) <= 12);

-- Format YYYY-NNNN (2026-0001, 2026-0002, ...). The count starts again every year.
-- It is made only once per allocation, so the number stays the same on every print.
create function private.ensure_ruv_number(p_allocation_id bigint) returns text
language plpgsql as $$
declare
    v_number text;
    v_prefix text;
    v_next integer;
begin
    select ruv_number into v_number from allocations where id = p_allocation_id;
    if v_number is not null then return v_number; end if;

    -- One at a time, so two prints never get the same number.
    perform pg_advisory_xact_lock(hashtext('allocations.ruv_number'));

    select ruv_number into v_number from allocations where id = p_allocation_id;
    if v_number is not null then return v_number; end if;

    v_prefix := extract(year from private.ph_now())::integer::text || '-';

    select coalesce(max(substring(ruv_number from length(v_prefix) + 1)::integer), 0) + 1
    into v_next
    from allocations
    where ruv_number like v_prefix || '%';

    v_number := v_prefix || lpad(v_next::text, 4, '0');
    update allocations set ruv_number = v_number where id = p_allocation_id;

    return v_number;
end $$;

-- ---------------------------------------------------------------- GET /vehicles/{id}/status
create function public.get_vehicle_status(p_vehicle_id bigint) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    v vehicles%rowtype;
    m vehicle_maintenance%rowtype;
begin
    perform private.require_admin_or_staff();

    select * into v from vehicles where id = p_vehicle_id;
    if not found then perform private.http_error(404, 'Vehicle not found.'); end if;

    select * into m from vehicle_maintenance
    where vehicle_id = v.id
    order by maintenance_date desc, id desc
    limit 1;

    return jsonb_build_object(
        'id', v.id,
        'plate_number', v.plate_number,
        'status', v.status,
        'last_maintenance', case when m.id is not null
            then jsonb_build_object('type', m.maintenance_type, 'date_performed', m.maintenance_date) end,
        'next_due_date', m.next_due_date
    );
end $$;

-- ---------------------------------------------------------------- GET /admins
-- Other active administrators who can receive a trip request.
create function public.list_admins() returns jsonb
language plpgsql security definer set search_path = public, private as $$
begin
    perform private.require_admin_or_staff();

    return jsonb_build_object('data', coalesce((
        select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.full_name, 'email', p.email) order by p.email)
        from profiles p
        where p.role = 'administrator' and p.is_active and p.id <> auth.uid()
    ), '[]'::jsonb));
end $$;

-- ================================================================ functions now open to staff
-- Same bodies as before. Only the permission check changed.

create or replace function public.allocation_options(
    p_start_date date default null,
    p_end_date date default null,
    p_ignore_trip_id bigint default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    s date;
    e date;
begin
    perform private.require_admin_or_staff();
    perform public.complete_finished_trips();

    s := coalesce(p_start_date, private.ph_today());
    e := coalesce(p_end_date, s);

    if e < s then
        perform private.fail('The end date must be on or after the start date.', 'end_date');
    end if;

    return jsonb_build_object(
        'requests', (
            select coalesce(jsonb_agg(private.request_option(r) order by r.trip_date, r.departure_time), '[]'::jsonb)
            from vehicle_requests r
            where r.status = 'approved'
              and not exists (select 1 from trips t where t.vehicle_request_id = r.id)
        ),
        'vehicles', (
            select coalesce(jsonb_agg(private.vehicle_option(v, br.reason) order by v.plate_number), '[]'::jsonb)
            from vehicles v
            left join private.busy_reasons(s, e, p_ignore_trip_id) br
                   on br.kind = 'vehicle' and br.subject_id = v.id
            where v.is_active and v.status in ('available', 'in_use')
        ),
        'drivers', (
            select coalesce(jsonb_agg(private.driver_option(d, x.reason) order by d.last_name, d.first_name), '[]'::jsonb)
            from drivers d
            left join private.busy_reasons(s, e, p_ignore_trip_id) br
                   on br.kind = 'driver' and br.subject_id = d.id
            cross join lateral (
                select coalesce(
                    br.reason,
                    case when not d.is_available and not exists (
                        select 1 from trips t
                        where t.driver_id = d.id and t.trip_status in ('scheduled', 'in_progress')
                    ) then 'Marked unavailable' end,
                    case when d.license_expiry_date < e then 'License expires before the trip date' end
                ) as reason
            ) x
        )
    );
end $$;

create or replace function public.add_driver(
    p_name text,
    p_contact_number text,
    p_license_number text,
    p_license_expiry_date date
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    v_parts text[];
    v_first text;
    v_last text;
    d drivers%rowtype;
begin
    perform private.require_admin_or_staff();

    if coalesce(trim(p_name), '') = '' then perform private.fail('The name field is required.', 'name'); end if;
    if char_length(p_name) > 120 then perform private.fail('The name may not be greater than 120 characters.', 'name'); end if;
    if coalesce(trim(p_contact_number), '') = '' then perform private.fail('The contact number field is required.', 'contact_number'); end if;
    if char_length(p_contact_number) > 20 then perform private.fail('The contact number may not be greater than 20 characters.', 'contact_number'); end if;
    if coalesce(trim(p_license_number), '') = '' then perform private.fail('The license number field is required.', 'license_number'); end if;
    if p_license_expiry_date is null then perform private.fail('The license expiry date field is required.', 'license_expiry_date'); end if;
    if exists (select 1 from drivers where license_number = p_license_number) then
        perform private.fail('The license number has already been taken.', 'license_number');
    end if;

    v_parts := regexp_split_to_array(trim(p_name), '\s+');
    if cardinality(v_parts) > 1 then
        v_last := v_parts[cardinality(v_parts)];
        v_first := array_to_string(v_parts[1:cardinality(v_parts) - 1], ' ');
    else
        v_last := v_parts[1];
        v_first := v_parts[1];
    end if;

    insert into drivers (first_name, last_name, contact_number, license_number, license_expiry_date, is_available)
    values (v_first, v_last, p_contact_number, p_license_number, p_license_expiry_date, true)
    returning * into d;

    return jsonb_build_object('data', private.driver_option(d));
end $$;

create or replace function public.add_vehicle(
    p_plate_number text,
    p_vehicle_model text,
    p_vehicle_type text default null,
    p_capacity integer default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    v vehicles%rowtype;
begin
    perform private.require_admin_or_staff();

    if coalesce(trim(p_plate_number), '') = '' then perform private.fail('The plate number field is required.', 'plate_number'); end if;
    if char_length(p_plate_number) > 20 then perform private.fail('The plate number may not be greater than 20 characters.', 'plate_number'); end if;
    if exists (select 1 from vehicles where plate_number = p_plate_number) then
        perform private.fail('The plate number has already been taken.', 'plate_number');
    end if;
    if coalesce(trim(p_vehicle_model), '') = '' then perform private.fail('The vehicle model field is required.', 'vehicle_model'); end if;
    if p_capacity is not null and (p_capacity < 1 or p_capacity > 100) then
        perform private.fail('The capacity must be between 1 and 100.', 'capacity');
    end if;

    insert into vehicles (plate_number, vehicle_model, vehicle_type, capacity, status, is_active)
    values (p_plate_number, p_vehicle_model, coalesce(nullif(trim(p_vehicle_type), ''), 'Not specified'),
            p_capacity, 'available', true)
    returning * into v;

    return jsonb_build_object('data', private.vehicle_option(v));
end $$;

create or replace function public.approve_reschedule(p_request_id bigint, p_admin_reason text default null) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    rr reschedule_requests%rowtype;
begin
    perform private.require_admin_or_staff();

    select * into rr from reschedule_requests where id = p_request_id for update;
    if not found then perform private.http_error(404, 'Reschedule request not found.'); end if;

    if rr.status <> 'pending' then
        perform private.fail(format('This request is already %s.', rr.status));
    end if;

    perform private.move_trip(rr.trip_id, rr.new_date);

    update reschedule_requests
    set status = 'approved', handled_by = auth.uid(), handled_at = now(), admin_reason = p_admin_reason
    where id = rr.id;

    return rr.id;
end $$;

create or replace function public.disapprove_reschedule(p_request_id bigint, p_admin_reason text) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    rr reschedule_requests%rowtype;
begin
    perform private.require_admin_or_staff();

    select * into rr from reschedule_requests where id = p_request_id for update;
    if not found then perform private.http_error(404, 'Reschedule request not found.'); end if;

    if rr.status <> 'pending' then
        perform private.fail(format('This request is already %s.', rr.status));
    end if;

    if coalesce(trim(p_admin_reason), '') = '' then
        perform private.fail('The admin reason field is required.', 'admin_reason');
    end if;

    update reschedule_requests
    set status = 'disapproved', handled_by = auth.uid(), handled_at = now(), admin_reason = p_admin_reason
    where id = rr.id;

    return rr.id;
end $$;

create or replace function public.reschedule_trip(p_allocation_id bigint, p_new_date date, p_reason text) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    al allocations%rowtype;
    v_old date;
    v_id bigint;
begin
    perform private.require_admin_or_staff();

    select * into al from allocations where id = p_allocation_id;
    if not found then perform private.http_error(404, 'Allocation not found.'); end if;

    if p_new_date is null then perform private.fail('The new date field is required.', 'new_date'); end if;
    if p_new_date < private.ph_today() then
        perform private.fail('The new date must be today or a later date.', 'new_date');
    end if;
    if coalesce(trim(p_reason), '') = '' then perform private.fail('The reason field is required.', 'reason'); end if;

    v_old := private.move_trip(al.trip_id, p_new_date);

    delete from reschedule_requests where trip_id = al.trip_id and status = 'pending';

    insert into reschedule_requests (trip_id, requested_by, old_date, new_date, reason,
                                     status, handled_by, handled_at)
    values (al.trip_id, auth.uid(), v_old, p_new_date, p_reason, 'approved', auth.uid(), now())
    returning id into v_id;

    return v_id;
end $$;

-- Print data for the "Request for Use of Vehicle" form. Now includes the RUV number.
create or replace function public.get_vehicle_request_print(p_allocation_id bigint) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    al allocations%rowtype;
    t trips%rowtype;
    r vehicle_requests%rowtype;
    v vehicles%rowtype;
    d drivers%rowtype;
    pr profiles%rowtype;
    v_end date;
    v_ruv text;
begin
    perform private.require_admin_or_staff();

    select * into al from allocations where id = p_allocation_id;
    if not found then perform private.http_error(404, 'Allocation not found.'); end if;

    select * into t from trips where id = al.trip_id;
    select * into r from vehicle_requests where id = t.vehicle_request_id;
    select * into v from vehicles where id = al.vehicle_id;
    select * into d from drivers where id = al.driver_id;
    select * into pr from profiles where id = r.requester_id;

    if r.id is null or r.status <> 'approved' or v.id is null or d.id is null then
        perform private.fail('Only approved requests with a vehicle and driver assigned can be printed.');
    end if;

    v_ruv := private.ensure_ruv_number(al.id);
    v_end := coalesce(r.trip_end_date, r.trip_date);

    return jsonb_build_object(
        'ruvNumber', v_ruv,
        'requestNo', r.id,
        'official', upper(coalesce(pr.full_name, '')),
        'position', coalesce(pr.position, ''),
        'destination', r.destination,
        'purpose', r.purpose,
        'passengers', r.passengers,
        'travelDate', case when v_end = r.trip_date
                           then to_char(r.trip_date, 'FMMonth FMDD, YYYY')
                           else to_char(r.trip_date, 'FMMonth FMDD, YYYY') || ' to ' || to_char(v_end, 'FMMonth FMDD, YYYY') end,
        'days', r.travel_days,
        'tripType', r.trip_type,
        'departure', to_char(timestamp '2000-01-01' + r.departure_time, 'FMHH12:MI AM'),
        'dateRequested', to_char(r.request_date at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY'),
        'timeRequested', to_char(r.request_date at time zone 'Asia/Manila', 'FMHH12:MI AM'),
        'plateNumber', v.plate_number,
        'driverName', d.full_name,
        'chiefMotorpool', (select value from app_settings where key = 'chief_motorpool'),
        'unitHeadGsu', (select value from app_settings where key = 'unit_head_gsu')
    );
end $$;

-- ---------------------------------------------------------------- permissions
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;