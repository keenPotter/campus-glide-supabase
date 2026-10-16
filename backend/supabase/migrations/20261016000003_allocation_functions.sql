-- AllocationService, AllocationController and AllocationQuickAddController as Postgres functions.
-- Internal helpers live in the `private` schema (not reachable from the API).
-- Functions in `public` are the API (supabase.rpc) and run as SECURITY DEFINER with an admin/faculty check.

-- ---------------------------------------------------------------- error helpers
-- PostgREST turns SQLSTATE 'PTnnn' into HTTP status nnn. `detail` is returned as `details`.
create function private.http_error(p_status int, p_message text) returns void
language plpgsql as $$
begin
    raise exception '%', p_message using errcode = 'PT' || p_status::text;
end $$;

-- Validation error in the Laravel shape: { message, errors: { field: [message] } }
create function private.fail(p_message text, p_field text default null) returns void
language plpgsql as $$
begin
    raise exception '%', p_message
        using errcode = 'PT422',
              detail = jsonb_build_object(
                  'errors',
                  case when p_field is null then '{}'::jsonb
                       else jsonb_build_object(p_field, jsonb_build_array(p_message)) end
              )::text;
end $$;

create function private.require_admin() returns void
language plpgsql as $$
begin
    if not public.is_admin() then
        perform private.http_error(403, 'You are not authorized to perform this action.');
    end if;
end $$;

create function private.require_faculty() returns void
language plpgsql as $$
begin
    if not public.is_faculty() then
        perform private.http_error(403, 'You are not authorized to perform this action.');
    end if;
end $$;

-- ---------------------------------------------------------------- option shapes (dropdowns)
create function private.request_option(r public.vehicle_requests) returns jsonb
language sql stable as $$
    select jsonb_build_object(
        'id', r.id,
        'label', format('#%s · %s · %s %s', r.id, r.destination, r.trip_date, left(r.departure_time::text, 5)),
        'destination', r.destination,
        'purpose', r.purpose,
        'requester', (select p.full_name from public.profiles p where p.id = r.requester_id),
        'trip_date', r.trip_date,
        'trip_end_date', r.trip_end_date,
        'trip_type', r.trip_type,
        'departure_time', r.departure_time,
        'estimated_return_time', r.estimated_return_time,
        'passengers', r.passengers,
        'number_of_passengers', r.number_of_passengers
    )
$$;

create function private.vehicle_option(v public.vehicles, p_reason text default null) returns jsonb
language sql stable as $$
    select jsonb_build_object(
        'id', v.id,
        'label', v.plate_number || ' — ' || v.vehicle_model
                 || case when coalesce(v.capacity, 0) > 0 then ' (' || v.capacity || ' seats)' else '' end,
        'vehicle_model', v.vehicle_model,
        'plate_number', v.plate_number,
        'capacity', v.capacity,
        'available', p_reason is null,
        'unavailable_reason', p_reason
    )
$$;

create function private.driver_option(d public.drivers, p_reason text default null) returns jsonb
language sql stable as $$
    select jsonb_build_object(
        'id', d.id,
        'label', coalesce(nullif(d.full_name, ''), 'Driver #' || d.id)
                 || coalesce(' · ' || d.contact_number, '')
                 || coalesce(' (Lic. exp. ' || to_char(d.license_expiry_date, 'Mon YYYY') || ')', ''),
        'name', coalesce(nullif(d.full_name, ''), 'Driver #' || d.id),
        'contact_number', d.contact_number,
        'license_expiry_date', d.license_expiry_date,
        'available', p_reason is null,
        'unavailable_reason', p_reason
    )
$$;

-- ---------------------------------------------------------------- availability
-- Active trips that share at least one day with the given date range.
create function private.busy_trips(p_start date, p_end date, p_ignore bigint default null)
returns setof public.trips
language sql stable as $$
    select t.*
    from public.trips t
    left join public.vehicle_requests vr on vr.id = t.vehicle_request_id
    where t.trip_status in ('scheduled', 'in_progress')
      and t.trip_date <= p_end
      and coalesce(vr.trip_end_date, t.trip_date) >= p_start
      and (p_ignore is null or t.id <> p_ignore)
$$;

-- Vehicles and drivers that are NOT available on the given dates, with the reason.
create function private.busy_reasons(p_start date, p_end date, p_ignore bigint default null)
returns table (kind text, subject_id bigint, reason text)
language sql stable as $$
    select 'vehicle'::text, b.vehicle_id,
           case when bool_or(b.trip_status = 'in_progress')
                then 'On a trip (in progress)' else 'Has a scheduled trip on this date' end
    from private.busy_trips(p_start, p_end, p_ignore) b
    group by b.vehicle_id
    union all
    select 'driver'::text, b.driver_id,
           case when bool_or(b.trip_status = 'in_progress')
                then 'On a trip (in progress)' else 'Has a scheduled trip on this date' end
    from private.busy_trips(p_start, p_end, p_ignore) b
    group by b.driver_id
$$;

-- The first and last day of a request's trip. With p_new_date, the whole range is moved to start there.
create function private.trip_range(p_request_id bigint, p_new_date date default null,
                                   out start_date date, out end_date date)
language plpgsql as $$
declare
    r vehicle_requests%rowtype;
    v_shift integer;
begin
    select * into r from vehicle_requests where id = p_request_id;
    start_date := r.trip_date;
    end_date := coalesce(r.trip_end_date, r.trip_date);

    if p_new_date is not null then
        v_shift := p_new_date - start_date;
        end_date := end_date + v_shift;
        start_date := p_new_date;
    end if;
end $$;

-- ---------------------------------------------------------------- assertions
create function private.assert_license_valid_on(d public.drivers, p_date date) returns void
language plpgsql as $$
begin
    if d.license_expiry_date is not null and d.license_expiry_date < p_date then
        perform private.fail('This driver''s license expires before the trip date.', 'driver_id');
    end if;
end $$;

create function private.assert_vehicle_ready(v public.vehicles) returns void
language plpgsql as $$
begin
    -- 'in_use' is allowed: the dates block it (assert_no_conflicts), not the status.
    if not v.is_active or v.status not in ('available', 'in_use') then
        perform private.fail(
            format('This vehicle is currently ''%s'' and is not ready for dispatch.', v.status), 'vehicle_id');
    end if;
end $$;

create function private.assert_driver_ready(d public.drivers, p_last_trip_date date) returns void
language plpgsql as $$
begin
    -- Unavailable only because of another trip is fine (conflicts handle it).
    -- It blocks only when the driver was marked unavailable by hand and has no active trip.
    if not d.is_available and not exists (
        select 1 from trips where driver_id = d.id and trip_status in ('scheduled', 'in_progress')
    ) then
        perform private.fail('This driver is currently marked unavailable.', 'driver_id');
    end if;

    perform private.assert_license_valid_on(d, p_last_trip_date);
end $$;

-- Checks the vehicle AND the driver together and reports every conflict in one 422 response.
-- details = { errors, conflict (first), conflicts (all) } for the frontend conflict modal.
create function private.assert_no_conflicts(p_vehicle_id bigint, p_driver_id bigint,
                                            p_start date, p_end date, p_ignore bigint)
returns void
language plpgsql as $$
declare
    k text;
    bt trips%rowtype;
    v vehicles%rowtype;
    d drivers%rowtype;
    v_end date;
    c jsonb := '[]'::jsonb;
    errs jsonb := '{}'::jsonb;
    vmsgs text[] := '{}';
    dmsgs text[] := '{}';
    msg text;
    when_txt text;
    subject text;
    v_label text;
    d_label text;
begin
    foreach k in array array['vehicle', 'driver'] loop
        for bt in
            select * from private.busy_trips(p_start, p_end, p_ignore) x
            where (k = 'vehicle' and x.vehicle_id = p_vehicle_id)
               or (k = 'driver' and x.driver_id = p_driver_id)
        loop
            select * into v from vehicles where id = bt.vehicle_id;
            select * into d from drivers where id = bt.driver_id;
            select coalesce(trip_end_date, bt.trip_date) into v_end
            from vehicle_requests where id = bt.vehicle_request_id;

            v_label := trim(v.vehicle_model || ' (' || v.plate_number || ')');
            d_label := d.full_name;
            subject := case when k = 'vehicle' then v_label
                            else coalesce(nullif(d_label, ''), 'Driver #' || p_driver_id) end;

            when_txt := case
                when v_end = bt.trip_date then to_char(bt.trip_date, 'FMMonth FMDD, YYYY')
                else to_char(bt.trip_date, 'FMMonth FMDD, YYYY') || ' to ' || to_char(v_end, 'FMMonth FMDD, YYYY')
            end;

            msg := subject || ' is already scheduled on ' || when_txt || ' at ' || bt.departure_time::text
                   || case when bt.estimated_return_time is not null
                           then ' – ' || bt.estimated_return_time::text else '' end
                   || '.';

            c := c || jsonb_build_array(jsonb_build_object(
                'type', k,
                'subject', subject,
                'trip_id', bt.id,
                'date', bt.trip_date,
                'end_date', v_end,
                'start', bt.departure_time,
                'end', bt.estimated_return_time,
                'destination', bt.destination,
                'driver', d_label,
                'vehicle', v_label,
                'message', msg
            ));

            if k = 'vehicle' then vmsgs := vmsgs || msg; else dmsgs := dmsgs || msg; end if;
        end loop;
    end loop;

    if jsonb_array_length(c) = 0 then
        return;
    end if;

    if cardinality(vmsgs) > 0 then errs := errs || jsonb_build_object('vehicle_id', to_jsonb(vmsgs)); end if;
    if cardinality(dmsgs) > 0 then errs := errs || jsonb_build_object('driver_id', to_jsonb(dmsgs)); end if;

    raise exception '%', array_to_string(array(select x ->> 'message' from jsonb_array_elements(c) x), ' ')
        using errcode = 'PT422',
              detail = jsonb_build_object('errors', errs, 'conflict', c -> 0, 'conflicts', c)::text;
end $$;

create function private.assert_assignable(
    p_request_id bigint,
    p_vehicle_id bigint,
    p_driver_id bigint,
    p_current_trip_id bigint default null,
    p_new_date date default null,
    p_allow_pending boolean default false
) returns void
language plpgsql as $$
declare
    r vehicle_requests%rowtype;
    v vehicles%rowtype;
    d drivers%rowtype;
    cur trips%rowtype;
    s date;
    e date;
    v_existing bigint;
begin
    select * into r from vehicle_requests where id = p_request_id;
    select * into v from vehicles where id = p_vehicle_id;
    select * into d from drivers where id = p_driver_id;
    if p_current_trip_id is not null then
        select * into cur from trips where id = p_current_trip_id;
    end if;

    select start_date, end_date into s, e from private.trip_range(p_request_id, p_new_date);

    -- Request must be approved (a pending one passes when it is approved together with this assignment).
    if not (p_allow_pending and r.status = 'pending') and r.status <> 'approved' then
        perform private.fail('Only approved vehicle requests can be allocated a vehicle and driver.', 'vehicle_request_id');
    end if;

    select id into v_existing from trips where vehicle_request_id = r.id;
    if v_existing is not null and v_existing is distinct from p_current_trip_id then
        perform private.fail(
            format('This request already has a trip allocated (trip #%s).', v_existing), 'vehicle_request_id');
    end if;

    -- Conflicts first (so the conflict modal shows up first), then readiness.
    perform private.assert_no_conflicts(v.id, d.id, s, e, p_current_trip_id);

    if p_current_trip_id is null or v.id <> cur.vehicle_id then
        perform private.assert_vehicle_ready(v);
    end if;

    if p_current_trip_id is null or d.id <> cur.driver_id then
        perform private.assert_driver_ready(d, e);
    end if;

    -- A driver who is kept on the trip still needs a valid license on the new dates.
    if p_new_date is not null then
        perform private.assert_license_valid_on(d, e);
    end if;
end $$;

-- ---------------------------------------------------------------- trips: free / move
-- Frees a vehicle and a driver, unless another active trip still uses them.
-- Only an "in use" vehicle is reset, so a vehicle under maintenance keeps its status.
create function private.free_vehicle_and_driver(p_vehicle_id bigint, p_driver_id bigint) returns void
language plpgsql as $$
begin
    if not exists (select 1 from trips
                   where vehicle_id = p_vehicle_id and trip_status in ('scheduled', 'in_progress')) then
        update vehicles set status = 'available' where id = p_vehicle_id and status = 'in_use';
    end if;

    if not exists (select 1 from trips
                   where driver_id = p_driver_id and trip_status in ('scheduled', 'in_progress')) then
        update drivers set is_available = true, assigned_vehicle_id = null where id = p_driver_id;
    end if;
end $$;

-- Writes the new date on the trip and its vehicle request. No checks here.
-- The end date moves by the same number of days. Returns the old date.
create function private.shift_trip_date(p_trip_id bigint, p_new_date date) returns date
language plpgsql as $$
declare
    v_old date;
    v_request bigint;
    v_shift integer;
begin
    select trip_date, vehicle_request_id into v_old, v_request from trips where id = p_trip_id;
    v_shift := p_new_date - v_old;

    update trips set trip_date = p_new_date where id = p_trip_id;
    update vehicle_requests
    set trip_date = p_new_date,
        trip_end_date = trip_end_date + v_shift
    where id = v_request;

    return v_old;
end $$;

-- Moves a SCHEDULED trip after checking that its vehicle and driver are free on the new dates.
create function private.move_trip(p_trip_id bigint, p_new_date date) returns date
language plpgsql as $$
declare
    t trips%rowtype;
    d drivers%rowtype;
    s date;
    e date;
begin
    select * into t from trips where id = p_trip_id for update;

    if t.trip_status <> 'scheduled' then
        perform private.fail(
            format('Only scheduled trips can have their date changed (this trip is %s).', t.trip_status), 'new_date');
    end if;

    if p_new_date = t.trip_date then
        perform private.fail('The new date is the same as the current date.', 'new_date');
    end if;

    select * into d from drivers where id = t.driver_id;
    select start_date, end_date into s, e from private.trip_range(t.vehicle_request_id, p_new_date);

    perform private.assert_license_valid_on(d, e);
    perform private.assert_no_conflicts(t.vehicle_id, t.driver_id, s, e, t.id);

    return private.shift_trip_date(t.id, p_new_date);
end $$;

-- ================================================================ PUBLIC API (rpc)

-- Marks every trip whose return time has passed as completed and frees its vehicle and driver.
-- The end of a trip is the END date of its request plus the estimated return time.
-- Call it before listing trips/allocations (api.js does), or schedule it with pg_cron (see below).
create function public.complete_finished_trips() returns integer
language plpgsql security definer set search_path = public, private as $$
declare
    v_ids bigint[];
    t record;
begin
    select coalesce(array_agg(tr.id), '{}') into v_ids
    from trips tr
    left join vehicle_requests vr on vr.id = tr.vehicle_request_id
    where tr.trip_status in ('scheduled', 'in_progress')
      and tr.estimated_return_time is not null
      and tr.trip_date <= private.ph_today()
      and (coalesce(vr.trip_end_date, tr.trip_date) + tr.estimated_return_time) <= private.ph_now();

    if cardinality(v_ids) = 0 then
        return 0;
    end if;

    update trips set trip_status = 'completed' where id = any (v_ids);

    for t in select vehicle_id, driver_id from trips where id = any (v_ids) loop
        perform private.free_vehicle_and_driver(t.vehicle_id, t.driver_id);
    end loop;

    return cardinality(v_ids);
end $$;

-- Optional: run it every 5 minutes instead of relying on page loads.
-- (Enable the pg_cron extension in Dashboard > Database > Extensions first.)
-- select cron.schedule('complete-finished-trips', '*/5 * * * *', $$select public.complete_finished_trips()$$);

-- Fills the dropdowns for assigning a vehicle and driver. Administrators only.
-- Returns { requests, vehicles, drivers } (vehicles/drivers carry `available` and `unavailable_reason`).
create function public.allocation_options(
    p_start_date date default null,
    p_end_date date default null,
    p_ignore_trip_id bigint default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    s date;
    e date;
begin
    perform private.require_admin();
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
                    -- marked unavailable by hand (not because of a trip)
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

-- Creates the trip and the allocation record together. Returns the allocation id.
-- With p_approve_request = true, a PENDING request is approved in the same step.
create function public.create_allocation(
    p_vehicle_request_id bigint,
    p_vehicle_id bigint,
    p_driver_id bigint,
    p_notes text default null,
    p_approve_request boolean default false
) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    r vehicle_requests%rowtype;
    v vehicles%rowtype;
    d drivers%rowtype;
    v_approving boolean;
    v_trip_id bigint;
    v_allocation_id bigint;
begin
    perform private.require_admin();

    if p_notes is not null and char_length(p_notes) > 500 then
        perform private.fail('The notes may not be greater than 500 characters.', 'notes');
    end if;

    -- Lock the rows so two administrators cannot book the same vehicle/driver at the same time.
    select * into r from vehicle_requests where id = p_vehicle_request_id for update;
    if not found then perform private.fail('Vehicle request not found.', 'vehicle_request_id'); end if;

    select * into v from vehicles where id = p_vehicle_id for update;
    if not found then perform private.fail('Vehicle not found.', 'vehicle_id'); end if;

    select * into d from drivers where id = p_driver_id for update;
    if not found then perform private.fail('Driver not found.', 'driver_id'); end if;

    v_approving := coalesce(p_approve_request, false) and r.status = 'pending';

    perform private.assert_assignable(r.id, v.id, d.id, null, null, v_approving);

    -- Approval and assignment are saved together (one transaction per rpc call).
    if v_approving then
        update vehicle_requests
        set status = 'approved',
            disapproval_reason = null,
            approved_by = auth.uid(),
            approved_date = now()
        where id = r.id;
    end if;

    insert into trips (vehicle_request_id, vehicle_id, driver_id, trip_date, departure_time,
                       estimated_return_time, destination, purpose, trip_status)
    values (r.id, v.id, d.id, r.trip_date, r.departure_time,
            r.estimated_return_time, r.destination, r.purpose, 'scheduled')
    returning id into v_trip_id;

    insert into allocations (trip_id, vehicle_id, driver_id, allocated_by, allocation_date, notes)
    values (v_trip_id, v.id, d.id, auth.uid(), now(), p_notes)
    returning id into v_allocation_id;

    update vehicles set status = 'in_use' where id = v.id;
    update drivers set is_available = false, assigned_vehicle_id = v.id where id = d.id;

    return v_allocation_id;
end $$;

-- One call for everything on the Reassign window: vehicle, driver, trip date and trip status.
-- Returns the allocation id.
create function public.update_allocation(
    p_allocation_id bigint,
    p_vehicle_id bigint default null,
    p_driver_id bigint default null,
    p_status text default null,
    p_notes text default null,
    p_new_date date default null,
    p_reason text default null
) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    al allocations%rowtype;
    t trips%rowtype;
    v vehicles%rowtype;
    d drivers%rowtype;
    v_vehicle_changed boolean;
    v_driver_changed boolean;
    v_new_status text;
    v_status_changed boolean;
    v_was_active boolean;
    v_date_changed boolean;
    v_old_date date;
begin
    perform private.require_admin();

    select * into al from allocations where id = p_allocation_id;
    if not found then perform private.http_error(404, 'Allocation not found.'); end if;

    select * into t from trips where id = al.trip_id for update;

    select * into v from vehicles where id = coalesce(p_vehicle_id, al.vehicle_id) for update;
    if not found then perform private.fail('Vehicle not found.', 'vehicle_id'); end if;

    select * into d from drivers where id = coalesce(p_driver_id, al.driver_id) for update;
    if not found then perform private.fail('Driver not found.', 'driver_id'); end if;

    if p_status is not null and p_status not in ('scheduled', 'in_progress', 'completed') then
        perform private.fail('The selected status is invalid.', 'status');
    end if;

    if p_new_date is not null then
        if p_new_date < private.ph_today() then
            perform private.fail('The new date must be today or a later date.', 'new_date');
        end if;
        if coalesce(trim(p_reason), '') = '' then
            perform private.fail('Please give a reason for changing the date.', 'reason');
        end if;
    end if;

    v_vehicle_changed := v.id <> t.vehicle_id;
    v_driver_changed := d.id <> t.driver_id;
    v_new_status := coalesce(p_status, t.trip_status);
    v_status_changed := v_new_status <> t.trip_status;
    v_was_active := t.trip_status in ('scheduled', 'in_progress');
    v_date_changed := p_new_date is not null and p_new_date <> t.trip_date;

    -- A completed trip can no longer be changed (it could free a vehicle/driver another trip is using).
    if not v_was_active and (v_vehicle_changed or v_driver_changed or v_status_changed or v_date_changed) then
        perform private.fail(
            format('This trip is already %s and can no longer be changed. Create a new request instead.', t.trip_status),
            'status');
    end if;

    if v_date_changed and t.trip_status <> 'scheduled' then
        perform private.fail(
            format('Only scheduled trips can have their date changed (this trip is %s).', t.trip_status), 'new_date');
    end if;

    if v_was_active and (v_vehicle_changed or v_driver_changed or v_date_changed) then
        perform private.assert_assignable(
            t.vehicle_request_id, v.id, d.id, t.id,
            case when v_date_changed then p_new_date end
        );
    end if;

    update trips
    set vehicle_id = v.id, driver_id = d.id, trip_status = v_new_status
    where id = t.id;

    update allocations
    set vehicle_id = v.id, driver_id = d.id, notes = coalesce(p_notes, notes)
    where id = al.id;

    -- Free the old vehicle/driver (unless another active trip still uses them).
    if v_vehicle_changed or v_driver_changed then
        perform private.free_vehicle_and_driver(t.vehicle_id, t.driver_id);
    end if;

    if v_new_status <> 'completed' then
        update vehicles set status = 'in_use' where id = v.id;
        update drivers set is_available = false, assigned_vehicle_id = v.id where id = d.id;
    end if;

    -- The new date: move the trip and its request, and keep a record with the reason.
    if v_date_changed then
        v_old_date := private.shift_trip_date(t.id, p_new_date);

        -- A pending faculty request is no longer needed once the date is changed directly.
        delete from reschedule_requests where trip_id = t.id and status = 'pending';

        insert into reschedule_requests (trip_id, requested_by, old_date, new_date, reason,
                                         status, handled_by, handled_at)
        values (t.id, auth.uid(), v_old_date, p_new_date, p_reason, 'approved', auth.uid(), now());
    end if;

    -- A finished trip frees its vehicle and driver.
    if v_new_status = 'completed' then
        perform private.free_vehicle_and_driver(v.id, d.id);
    end if;

    return al.id;
end $$;

-- "Add new driver" from the allocation page. The last word of the name is the last name.
create function public.add_driver(
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
    perform private.require_admin();

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

-- "Add new vehicle" from the allocation page.
create function public.add_vehicle(
    p_plate_number text,
    p_vehicle_model text,
    p_vehicle_type text default null,
    p_capacity integer default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    v vehicles%rowtype;
begin
    perform private.require_admin();

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