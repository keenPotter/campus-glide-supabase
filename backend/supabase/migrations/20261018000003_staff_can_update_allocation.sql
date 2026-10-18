-- Staff can reassign an allocation (vehicle, driver, date and status),
-- matching UpdateAllocationRequest::authorize() in the Laravel version.
-- create_allocation stays administrator only, as in routes/api.php.
-- Same body as before. Only the permission check changed.

create or replace function public.update_allocation(
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
    perform private.require_admin_or_staff();

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

-- ---------------------------------------------------------------- permissions
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;