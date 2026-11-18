set check_function_bodies = off;

-- Active trips that share at least one day with the range (and overlap in time when times are given)
create or replace function public.busy_trips(p_start date, p_end date, p_ignore bigint, p_st time, p_et time)
returns setof public.trips language sql stable as $$
  select t.* from public.trips t
  left join public.vehicle_requests r on r.id = t.vehicle_request_id
  where t.trip_status in ('scheduled', 'in_progress')
    and t.trip_date <= p_end
    and coalesce(r.trip_end_date, t.trip_date) >= p_start
    and (p_ignore is null or t.id <> p_ignore)
    and (
      p_st is null or p_et is null
      or (
        (t.trip_date + t.departure_time) < (p_end + p_et)
        and (coalesce(r.trip_end_date, t.trip_date) + coalesce(t.estimated_return_time, time '23:59:59')) > (p_start + p_st)
      )
    ) $$;

create or replace function public.conflict_details(p_column text, p_id bigint, p_trip bigint) returns jsonb language plpgsql stable as $$
declare
  t public.trips; r public.vehicle_requests; v public.vehicles; d public.drivers;
  v_label text; d_label text; subj text; s date; e date; w text; msg text;
begin
  select * into t from public.trips where id = p_trip;
  select * into r from public.vehicle_requests where id = t.vehicle_request_id;
  select * into v from public.vehicles where id = t.vehicle_id;
  select * into d from public.drivers where id = t.driver_id;
  v_label := case when v.id is not null then btrim(v.vehicle_model || ' (' || v.plate_number || ')') end;
  d_label := nullif(public.full_name(d.first_name, d.last_name), '');
  subj := case when p_column = 'vehicle_id' then coalesce(v_label, 'Vehicle') else coalesce(d_label, 'Driver #' || p_id) end;
  s := t.trip_date;
  e := coalesce(r.trip_end_date, t.trip_date);
  w := case when e = s then to_char(s, 'FMMonth FMDD, YYYY')
            else to_char(s, 'FMMonth FMDD, YYYY') || ' to ' || to_char(e, 'FMMonth FMDD, YYYY') end;
  msg := subj || ' is already scheduled on ' || w || ' at ' || t.departure_time::text
         || coalesce(' – ' || t.estimated_return_time::text, '') || '.';
  return jsonb_build_object(
    'type', case when p_column = 'vehicle_id' then 'vehicle' else 'driver' end,
    'subject', subj, 'trip_id', t.id, 'date', s::text, 'end_date', e::text,
    'start', t.departure_time::text, 'end', t.estimated_return_time::text,
    'destination', t.destination, 'driver', d_label, 'vehicle', v_label, 'message', msg
  );
end $$;

-- Checks the vehicle AND the driver together and reports every conflict in one 422 response
create or replace function public.assert_no_conflicts(
  p_vehicle bigint, p_driver bigint, p_start date, p_end date, p_ignore bigint, p_st time, p_et time
) returns void language plpgsql as $$
declare c jsonb := '[]'::jsonb; errs jsonb := '{}'::jsonb; t record; item jsonb;
begin
  for t in select b.id from public.busy_trips(p_start, p_end, p_ignore, p_st, p_et) b where b.vehicle_id = p_vehicle order by b.id loop
    c := c || jsonb_build_array(public.conflict_details('vehicle_id', p_vehicle, t.id));
  end loop;
  for t in select b.id from public.busy_trips(p_start, p_end, p_ignore, p_st, p_et) b where b.driver_id = p_driver order by b.id loop
    c := c || jsonb_build_array(public.conflict_details('driver_id', p_driver, t.id));
  end loop;

  if jsonb_array_length(c) = 0 then
    return;
  end if;

  for item in select e from jsonb_array_elements(c) e loop
    errs := public.err_add(errs, case when item ->> 'type' = 'vehicle' then 'vehicle_id' else 'driver_id' end, item ->> 'message');
  end loop;

  perform public.fail(
    422,
    (select string_agg(x ->> 'message', ' ') from jsonb_array_elements(c) x),
    errs,
    jsonb_build_object('conflict', c -> 0, 'conflicts', c)
  );
end $$;

create or replace function public.assert_license(p_driver bigint, p_date date) returns void language plpgsql as $$
declare v_exp date;
begin
  select license_expiry_date into v_exp from public.drivers where id = p_driver;
  if v_exp is not null and v_exp < p_date then
    perform public.fail_validation('driver_id', 'This driver''s license expires before the trip date.');
  end if;
end $$;

-- First and last day of a request's trip. With p_new, the whole range moves to start on that date.
create or replace function public.trip_range(p_request bigint, p_new date default null, out o_start date, out o_end date)
language plpgsql stable as $$
declare r public.vehicle_requests; v_shift int;
begin
  select * into r from public.vehicle_requests where id = p_request;
  o_start := r.trip_date;
  o_end := coalesce(r.trip_end_date, r.trip_date);
  if p_new is not null then
    v_shift := p_new - o_start;
    o_end := o_end + v_shift;
    o_start := p_new;
  end if;
end $$;

create or replace function public.assert_assignable(
  p_request bigint, p_vehicle bigint, p_driver bigint,
  p_current_trip bigint default null, p_new_date date default null, p_allow_pending boolean default false
) returns void language plpgsql as $$
declare
  r public.vehicle_requests; v public.vehicles; d public.drivers; ct public.trips;
  v_start date; v_end date; v_existing bigint;
begin
  select * into r from public.vehicle_requests where id = p_request;
  select * into v from public.vehicles where id = p_vehicle;
  select * into d from public.drivers where id = p_driver;
  if p_current_trip is not null then
    select * into ct from public.trips where id = p_current_trip;
  end if;
  select o_start, o_end into v_start, v_end from public.trip_range(p_request, p_new_date);

  if not (p_allow_pending and r.status = 'pending') and r.status <> 'approved' then
    perform public.fail_validation('vehicle_request_id', 'Only approved vehicle requests can be allocated a vehicle and driver.');
  end if;

  select id into v_existing from public.trips where vehicle_request_id = p_request limit 1;
  if v_existing is not null and v_existing is distinct from p_current_trip then
    perform public.fail_validation('vehicle_request_id', 'This request already has a trip allocated (trip #' || v_existing || ').');
  end if;

  perform public.assert_no_conflicts(p_vehicle, p_driver, v_start, v_end, p_current_trip, r.departure_time, r.estimated_return_time);

  if ct.id is null or p_vehicle <> ct.vehicle_id then
    if not v.is_active or v.status not in ('available', 'in_use') then
      perform public.fail_validation('vehicle_id', 'This vehicle is currently ''' || v.status || ''' and is not ready for dispatch.');
    end if;
  end if;

  if ct.id is null or p_driver <> ct.driver_id then
    if not d.is_available and not exists (
      select 1 from public.trips where driver_id = p_driver and trip_status in ('scheduled', 'in_progress')
    ) then
      perform public.fail_validation('driver_id', 'This driver is currently marked unavailable.');
    end if;
    perform public.assert_license(p_driver, v_end);
  end if;

  if p_new_date is not null then
    perform public.assert_license(p_driver, v_end);
  end if;
end $$;

-- Frees a vehicle and a driver, unless another active trip still uses them
create or replace function public.free_vehicle_and_driver(p_vehicle bigint, p_driver bigint) returns void language plpgsql as $$
begin
  if not exists (select 1 from public.trips where vehicle_id = p_vehicle and trip_status in ('scheduled', 'in_progress')) then
    update public.vehicles set status = 'available' where id = p_vehicle and status = 'in_use';
  end if;
  if not exists (select 1 from public.trips where driver_id = p_driver and trip_status in ('scheduled', 'in_progress')) then
    update public.drivers set is_available = true, assigned_vehicle_id = null where id = p_driver;
  end if;
end $$;

-- Marks every trip whose return time has passed as completed
create or replace function public.complete_finished_trips() returns int language plpgsql security definer set search_path = public as $$
declare v_ids bigint[]; t record;
begin
  select coalesce(array_agg(x.id), '{}') into v_ids
  from public.trips x
  left join public.vehicle_requests r on r.id = x.vehicle_request_id
  where x.trip_status in ('scheduled', 'in_progress')
    and x.estimated_return_time is not null
    and x.trip_date <= public.app_today()
    and (coalesce(r.trip_end_date, x.trip_date) + x.estimated_return_time) <= public.app_now();

  if cardinality(v_ids) = 0 then
    return 0;
  end if;

  update public.trips set trip_status = 'completed' where id = any (v_ids);

  for t in select vehicle_id, driver_id from public.trips where id = any (v_ids) loop
    perform public.free_vehicle_and_driver(t.vehicle_id, t.driver_id);
  end loop;

  return cardinality(v_ids);
end $$;

create or replace function public.shift_trip_date(p_trip bigint, p_new date) returns date language plpgsql as $$
declare t public.trips; v_old date; v_shift int;
begin
  select * into t from public.trips where id = p_trip;
  v_old := t.trip_date;
  v_shift := p_new - v_old;
  update public.trips set trip_date = p_new where id = p_trip;
  update public.vehicle_requests set trip_date = p_new, trip_end_date = trip_end_date + v_shift where id = t.vehicle_request_id;
  return v_old;
end $$;

create or replace function public.move_trip(p_trip bigint, p_new date) returns date language plpgsql as $$
declare t public.trips; v_start date; v_end date;
begin
  select * into t from public.trips where id = p_trip;
  if t.trip_status <> 'scheduled' then
    perform public.fail_validation('new_date', 'Only scheduled trips can have their date changed (this trip is ' || t.trip_status || ').');
  end if;
  if p_new = t.trip_date then
    perform public.fail_validation('new_date', 'The new date is the same as the current date.');
  end if;
  select o_start, o_end into v_start, v_end from public.trip_range(t.vehicle_request_id, p_new);
  perform public.assert_license(t.driver_id, v_end);
  perform public.assert_no_conflicts(t.vehicle_id, t.driver_id, v_start, v_end, t.id, t.departure_time, t.estimated_return_time);
  return public.shift_trip_date(p_trip, p_new);
end $$;

-- Creates the trip and the allocation together (and approves a pending request when asked)
create or replace function public.allocate_request(
  p_request bigint, p_vehicle bigint, p_driver bigint, p_by bigint, p_notes text, p_approve boolean
) returns bigint language plpgsql as $$
declare r public.vehicle_requests; v_trip bigint; v_alloc bigint;
begin
  perform 1 from public.vehicles where id = p_vehicle for update;
  perform 1 from public.drivers where id = p_driver for update;

  perform public.assert_assignable(p_request, p_vehicle, p_driver, null, null, p_approve);
  select * into r from public.vehicle_requests where id = p_request;

  if p_approve and r.status = 'pending' then
    update public.vehicle_requests
      set status = 'approved', disapproval_reason = null, approved_by = p_by, approved_date = now()
      where id = p_request;
  end if;

  insert into public.trips (vehicle_request_id, vehicle_id, driver_id, trip_date, departure_time, estimated_return_time, destination, purpose, trip_status)
  values (r.id, p_vehicle, p_driver, r.trip_date, r.departure_time, r.estimated_return_time, r.destination, r.purpose, 'scheduled')
  returning id into v_trip;

  insert into public.allocations (trip_id, vehicle_id, driver_id, allocated_by, allocation_date, notes)
  values (v_trip, p_vehicle, p_driver, p_by, now(), nullif(p_notes, ''))
  returning id into v_alloc;

  update public.vehicles set status = 'in_use' where id = p_vehicle;
  update public.drivers set is_available = false, assigned_vehicle_id = p_vehicle where id = p_driver;

  return v_alloc;
end $$;

-- RUV No. (YYYY-NNNN). Made once per allocation, the count starts again every year.
create or replace function public.ensure_ruv_number(p_id bigint) returns text language plpgsql as $$
declare v_cur text; v_prefix text; v_last text; v_next int;
begin
  perform pg_advisory_xact_lock(7001);
  select ruv_number into v_cur from public.allocations where id = p_id for update;
  if v_cur is not null then
    return v_cur;
  end if;
  v_prefix := extract(year from public.app_today())::int::text || '-';
  select max(ruv_number) into v_last from public.allocations where ruv_number like v_prefix || '%';
  v_next := coalesce(substr(v_last, length(v_prefix) + 1)::int, 0) + 1;
  v_cur := v_prefix || lpad(v_next::text, 4, '0');
  update public.allocations set ruv_number = v_cur where id = p_id;
  return v_cur;
end $$;

-- Field checks shared by the request forms
create or replace function public.validate_trip_fields(b jsonb, p_check_today boolean) returns jsonb language plpgsql as $$
declare e jsonb := '{}'::jsonb; f text; d1 date; d2 date; t1 time; t2 time; n int;
begin
  foreach f in array array['destination', 'purpose', 'trip_date', 'trip_end_date', 'trip_type', 'departure_time', 'estimated_return_time', 'passengers', 'number_of_passengers'] loop
    if coalesce(btrim(b ->> f), '') = '' then
      e := public.err_add(e, f, 'The ' || replace(f, '_', ' ') || ' field is required.');
    end if;
  end loop;

  foreach f in array array['destination', 'purpose', 'passengers'] loop
    if length(coalesce(b ->> f, '')) > 255 then
      e := public.err_add(e, f, 'The ' || replace(f, '_', ' ') || ' field must not be greater than 255 characters.');
    end if;
  end loop;

  d1 := public.try_date(b ->> 'trip_date');
  d2 := public.try_date(b ->> 'trip_end_date');
  if coalesce(b ->> 'trip_date', '') <> '' and d1 is null then e := public.err_add(e, 'trip_date', 'The trip date field must be a valid date.'); end if;
  if coalesce(b ->> 'trip_end_date', '') <> '' and d2 is null then e := public.err_add(e, 'trip_end_date', 'The trip end date field must be a valid date.'); end if;
  if p_check_today and d1 is not null and d1 < public.app_today() then
    e := public.err_add(e, 'trip_date', 'The trip date field must be a date after or equal to today.');
  end if;
  if d1 is not null and d2 is not null and d2 < d1 then
    e := public.err_add(e, 'trip_end_date', 'The trip end date field must be a date after or equal to trip date.');
  end if;

  if coalesce(b ->> 'trip_type', '') <> '' and (b ->> 'trip_type') not in ('inclusive', 'exclusive') then
    e := public.err_add(e, 'trip_type', 'The selected trip type is invalid.');
  end if;

  t1 := public.try_time(b ->> 'departure_time');
  t2 := public.try_time(b ->> 'estimated_return_time');
  if coalesce(b ->> 'departure_time', '') <> '' and t1 is null then e := public.err_add(e, 'departure_time', 'The departure time field must match the format H:i.'); end if;
  if coalesce(b ->> 'estimated_return_time', '') <> '' and t2 is null then e := public.err_add(e, 'estimated_return_time', 'The estimated return time field must match the format H:i.'); end if;
  if t1 is not null and t2 is not null and t2 <= t1 then
    e := public.err_add(e, 'estimated_return_time', 'The estimated return time field must be a time after departure time.');
  end if;

  n := public.try_int(b ->> 'number_of_passengers');
  if coalesce(b ->> 'number_of_passengers', '') <> '' and (n is null or n < 1) then
    e := public.err_add(e, 'number_of_passengers', 'The number of passengers field must be at least 1.');
  end if;

  return e;
end $$;