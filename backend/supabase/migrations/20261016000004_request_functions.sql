-- VehicleRequestController, RescheduleRequestController and the two print controllers.

-- Approve or disapprove a PENDING request (administrators only).
create function public.update_vehicle_request_status(
    p_request_id bigint,
    p_status text,
    p_remarks text default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    r vehicle_requests%rowtype;
begin
    perform private.require_admin();

    select * into r from vehicle_requests where id = p_request_id for update;
    if not found then perform private.http_error(404, 'Vehicle request not found.'); end if;

    if r.status <> 'pending' then
        perform private.http_error(403, 'This action is unauthorized.');
    end if;

    if p_status not in ('approved', 'disapproved') then
        perform private.fail('The selected status is invalid.', 'status');
    end if;

    if p_status = 'disapproved' and coalesce(trim(p_remarks), '') = '' then
        perform private.fail('Please provide a reason for disapproval.', 'remarks');
    end if;

    update vehicle_requests
    set status = p_status,
        disapproval_reason = case when p_status = 'approved' then null else p_remarks end,
        approved_by = auth.uid(),
        approved_date = case when p_status = 'approved' then now() end
    where id = r.id
    returning * into r;

    return to_jsonb(r);
end $$;

-- Faculty edit their own request.
-- Editing an approved request (a reason is required) makes it a new pending request:
-- its trip is deleted, the vehicle and driver are freed, and the administrator must approve it again.
create function public.edit_vehicle_request(
    p_request_id bigint,
    p_trip_date date,
    p_trip_end_date date,
    p_trip_type text,
    p_departure_time time,
    p_destination text,
    p_purpose text,
    p_estimated_return_time time,
    p_passengers text,
    p_number_of_passengers integer,
    p_edit_reason text default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    r vehicle_requests%rowtype;
    t trips%rowtype;
    v_was_approved boolean;
    v_has_trip boolean;
begin
    perform private.require_faculty();

    select * into r from vehicle_requests where id = p_request_id for update;
    if not found or r.requester_id <> auth.uid() or r.status not in ('pending', 'approved') then
        perform private.http_error(403, 'This action is unauthorized.');
    end if;

    v_was_approved := r.status = 'approved';

    if v_was_approved and coalesce(trim(p_edit_reason), '') = '' then
        perform private.fail('Please give a reason for editing this approved request.', 'edit_reason');
    end if;
    if p_edit_reason is not null and char_length(p_edit_reason) > 500 then
        perform private.fail('The edit reason may not be greater than 500 characters.', 'edit_reason');
    end if;
    if p_trip_end_date < p_trip_date then
        perform private.fail('The trip end date must be on or after the trip date.', 'trip_end_date');
    end if;
    if p_trip_type not in ('inclusive', 'exclusive') then
        perform private.fail('The selected trip type is invalid.', 'trip_type');
    end if;
    if p_estimated_return_time <= p_departure_time then
        perform private.fail('The estimated return time must be after the departure time.', 'estimated_return_time');
    end if;
    if p_number_of_passengers < 1 then
        perform private.fail('The number of passengers must be at least 1.', 'number_of_passengers');
    end if;

    select * into t from trips where vehicle_request_id = r.id;
    v_has_trip := found;

    -- A trip that already started or finished cannot be undone by editing the request.
    if v_has_trip and t.trip_status <> 'scheduled' then
        perform private.fail(format(
            'This request can no longer be edited because its trip is already %s.', t.trip_status));
    end if;

    -- The allocation record, date change requests and shared copies are deleted with the trip.
    if v_has_trip then
        delete from trips where id = t.id;
        perform private.free_vehicle_and_driver(t.vehicle_id, t.driver_id);
    end if;

    update vehicle_requests
    set trip_date = p_trip_date,
        trip_end_date = p_trip_end_date,
        trip_type = p_trip_type,
        departure_time = p_departure_time,
        destination = p_destination,
        purpose = p_purpose,
        estimated_return_time = p_estimated_return_time,
        passengers = p_passengers,
        number_of_passengers = p_number_of_passengers,
        edit_reason = p_edit_reason,
        status = case when v_was_approved then 'pending' else status end,
        approved_by = case when v_was_approved then null else approved_by end,
        approved_date = case when v_was_approved then null else approved_date end
    where id = r.id
    returning * into r;

    return jsonb_build_object('message', 'Vehicle request updated successfully.', 'data', to_jsonb(r));
end $$;

-- ---------------------------------------------------------------- date changes
-- Faculty ask for a change; they do not move the trip. Returns the reschedule request id.
create function public.request_reschedule(
    p_allocation_id bigint,
    p_new_date date,
    p_reason text
) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    t trips%rowtype;
    r vehicle_requests%rowtype;
    v_id bigint;
begin
    perform private.require_faculty();

    select t2.* into t
    from allocations a join trips t2 on t2.id = a.trip_id
    where a.id = p_allocation_id;
    if not found then perform private.http_error(404, 'Allocation not found.'); end if;

    select * into r from vehicle_requests where id = t.vehicle_request_id;
    if r.requester_id <> auth.uid() then
        perform private.http_error(403, 'You may only request a date change for your own trips.');
    end if;

    if p_new_date is null then perform private.fail('The new date field is required.', 'new_date'); end if;
    if p_new_date < private.ph_today() then
        perform private.fail('The new date must be today or a later date.', 'new_date');
    end if;
    if coalesce(trim(p_reason), '') = '' then perform private.fail('The reason field is required.', 'reason'); end if;
    if char_length(p_reason) > 500 then perform private.fail('The reason may not be greater than 500 characters.', 'reason'); end if;

    if t.trip_status <> 'scheduled' then
        perform private.fail(format('A %s trip can no longer be rescheduled.', t.trip_status));
    end if;

    if exists (select 1 from reschedule_requests where trip_id = t.id and status = 'pending') then
        perform private.fail('This trip already has a pending date change request.');
    end if;

    if p_new_date = t.trip_date then
        perform private.fail('The new date is the same as the current date.');
    end if;

    insert into reschedule_requests (trip_id, requested_by, old_date, new_date, reason, status)
    values (t.id, auth.uid(), t.trip_date, p_new_date, p_reason, 'pending')
    returning id into v_id;

    return v_id;
end $$;

-- Moves the trip to the requested date. The conflict check runs first. The note is optional.
create function public.approve_reschedule(p_request_id bigint, p_admin_reason text default null) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    rr reschedule_requests%rowtype;
begin
    perform private.require_admin();

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

-- The trip is not touched. The reason is required, and the faculty member can see it.
create function public.disapprove_reschedule(p_request_id bigint, p_admin_reason text) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    rr reschedule_requests%rowtype;
begin
    perform private.require_admin();

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

-- Administrator reassigns the date directly. A reason is required.
create function public.reschedule_trip(p_allocation_id bigint, p_new_date date, p_reason text) returns bigint
language plpgsql security definer set search_path = public, private as $$
declare
    al allocations%rowtype;
    v_old date;
    v_id bigint;
begin
    perform private.require_admin();

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

-- ---------------------------------------------------------------- print data
-- The backend no longer renders HTML. These functions return the same values the Blade views received.
-- Move resources/views/print/*.blade.php into the frontend (a print route) and fill them from this JSON.
create function public.get_vehicle_request_print(p_allocation_id bigint) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    al allocations%rowtype;
    t trips%rowtype;
    r vehicle_requests%rowtype;
    v vehicles%rowtype;
    d drivers%rowtype;
    pr profiles%rowtype;
    v_end date;
begin
    perform private.require_admin();

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

    v_end := coalesce(r.trip_end_date, r.trip_date);

    return jsonb_build_object(
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

create function public.get_checklist_print(p_checklist_id bigint) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    c preventive_maintenance_checklists%rowtype;
    v vehicles%rowtype;
begin
    perform private.require_admin();

    select * into c from preventive_maintenance_checklists where id = p_checklist_id;
    if not found then perform private.http_error(404, 'Checklist not found.'); end if;
    select * into v from vehicles where id = c.vehicle_id;

    return jsonb_build_object(
        'pmuvNo', coalesce(c.pmuv_no, ''),
        'date', coalesce(to_char(c.inspection_date, 'Mon FMDD, YYYY'), ''),
        'vehicleModel', coalesce(v.vehicle_model, ''),
        'plateNumber', coalesce(v.plate_number, ''),
        'inspector', coalesce(c.inspector_mechanic, ''),
        'mileage', case when c.current_mileage is null then ''
                        else to_char(c.current_mileage, 'FM999,999,999,999') || ' km' end,
        'serviceDates', jsonb_build_array(
            jsonb_build_object('label', 'Oil change',     'value', coalesce(to_char(c.last_oil_change, 'Mon FMDD, YYYY'), '')),
            jsonb_build_object('label', 'Air filter',     'value', coalesce(to_char(c.last_air_filter_change, 'Mon FMDD, YYYY'), '')),
            jsonb_build_object('label', 'Cabin filter',   'value', coalesce(to_char(c.last_cabin_filter_change, 'Mon FMDD, YYYY'), '')),
            jsonb_build_object('label', 'Oil filter',     'value', coalesce(to_char(c.last_oil_filter_change, 'Mon FMDD, YYYY'), '')),
            jsonb_build_object('label', 'Engine tune-up', 'value', coalesce(to_char(c.last_engine_tune_up, 'Mon FMDD, YYYY'), ''))
        ),
        'items', jsonb_build_array(
            jsonb_build_object('label', 'Belts',                  'rating', c.belts_condition),
            jsonb_build_object('label', 'Hoses',                  'rating', c.hoses_condition),
            jsonb_build_object('label', 'Engine',                 'rating', c.engine_condition),
            jsonb_build_object('label', 'Heat / Air conditioning','rating', c.air_conditioning_condition),
            jsonb_build_object('label', 'Wipers',                 'rating', c.wipers_condition),
            jsonb_build_object('label', 'Headlights',             'rating', c.headlights_condition),
            jsonb_build_object('label', 'Driving lights',         'rating', c.driving_lights_condition),
            jsonb_build_object('label', 'Brake lights',           'rating', c.brake_lights_condition),
            jsonb_build_object('label', 'Hazard lights',          'rating', c.hazard_lights_condition),
            jsonb_build_object('label', 'Door locks',             'rating', c.door_locks_condition),
            jsonb_build_object('label', 'Windows / Windshield',   'rating', c.windows_windshield_condition),
            jsonb_build_object('label', 'Radio',                  'rating', c.radio_condition),
            jsonb_build_object('label', 'Tires',                  'rating', c.tires_condition),
            jsonb_build_object('label', 'Liquid levels',          'rating', c.liquid_levels_condition)
        ),
        'otherParts', coalesce(c.other_parts, ''),
        'remarks', coalesce(c.remarks, ''),
        'recommendation', coalesce(c.supervisor_recommendation, '')
    );
end $$;

-- ---------------------------------------------------------------- sorted request list
-- Pending requests first (soonest travel date on top), then the rest newest first.
-- PostgREST cannot order by CASE, so the sort keys are exposed as columns.
-- security_invoker keeps the RLS of vehicle_requests (faculty only see their own).
create view public.vehicle_requests_ordered with (security_invoker = true) as
select r.*,
       case when r.status = 'pending' then 0 else 1 end as sort_group,
       case when r.status = 'pending' then r.trip_date end as pending_trip_date,
       case when r.status = 'pending' then r.departure_time end as pending_departure_time
from public.vehicle_requests r;

-- ---------------------------------------------------------------- permissions
-- Only signed-in users may call the API functions. (Internal helpers are in `private`.)
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
grant select on public.vehicle_requests_ordered to authenticated;