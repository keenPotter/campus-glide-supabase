set check_function_bodies = off;

-- ================= session =================

create or replace function public.api_login_precheck(p_email text) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('found', exists (select 1 from public.profiles where lower(email) = lower(btrim(p_email)))) $$;

create or replace function public.api_me() returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v public.profiles;
begin
  if auth.uid() is null then perform public.fail(401, 'Unauthenticated.'); end if;
  v := public.me();
  if v.id is null then perform public.fail(403, 'No profile exists for this account.'); end if;
  return jsonb_build_object('data', public.res_user(v.id));
end $$;

create or replace function public.api_log_auth(p_action text) returns void language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_auth();
begin
  if p_action not in ('LOGIN', 'LOGOUT') then return; end if;
  perform public.log_action(v_me.id, p_action, 'users', v_me.id::text);
end $$;

create or replace function public.api_notifications_summary() returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator');
begin
  return jsonb_build_object('data', jsonb_build_object(
    'pending_requests', (select count(*) from public.vehicle_requests where status = 'pending'),
    'open_maintenance', (select count(*) from public.vehicle_maintenance where status = 'in_progress'),
    'needs_allocation', (select count(*) from public.vehicle_requests r where r.status in ('pending', 'approved') and not exists (select 1 from public.trips t where t.vehicle_request_id = r.id)),
    'pending_date_changes', (select count(*) from public.reschedule_requests where status = 'pending')
  ));
end $$;

-- ================= vehicle requests =================

create or replace function public.api_vehicle_requests_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_auth();
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_per int := least(greatest(coalesce(public.try_int(p_params ->> 'per_page'), 10), 1), 100);
  v_terms text[] := case when coalesce(btrim(p_params ->> 'search'), '') = '' then null else regexp_split_to_array(btrim(p_params ->> 'search'), '\s+') end;
  v_all bigint[]; v_ids bigint[];
begin
  select coalesce(array_agg(r.id order by r.created_at desc, r.id desc), '{}') into v_all
  from public.vehicle_requests r
  left join public.profiles q on q.id = r.requester_id
  where (v_me.role <> 'faculty' or r.requester_id = v_me.id)
    and (nullif(p_params ->> 'status', '') is null or r.status = p_params ->> 'status')
    and (nullif(p_params ->> 'trip_type', '') is null or r.trip_type = p_params ->> 'trip_type')
    and (nullif(p_params ->> 'year', '') is null or extract(year from r.trip_date) = public.try_int(p_params ->> 'year'))
    and (nullif(p_params ->> 'month', '') is null or extract(month from r.trip_date) = public.try_int(p_params ->> 'month'))
    and (v_terms is null or not exists (
      select 1 from unnest(v_terms) t where not (
        concat_ws(chr(1), r.destination, r.purpose, r.disapproval_reason, r.requester_name, r.requester_department,
                  r.requester_contact, q.first_name, q.last_name, q.email) ilike '%' || t || '%'
      )
    ));

  v_ids := v_all[(v_page - 1) * v_per + 1 : v_page * v_per];
  return public.page_result(public.collect('res_vehicle_request', v_ids), v_page, v_per, cardinality(v_all));
end $$;

create or replace function public.api_vehicle_request_show(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_auth(); r public.vehicle_requests;
begin
  select * into r from public.vehicle_requests where id = p_id;
  if r.id is null then perform public.fail(404, 'No query results for model [App\Models\VehicleRequest] ' || p_id); end if;
  if v_me.role = 'faculty' and r.requester_id is distinct from v_me.id then
    perform public.fail(403, 'You are not authorized to view this request.');
  end if;
  return jsonb_build_object('data', public.res_vehicle_request(p_id));
end $$;

create or replace function public.api_vehicle_request_create(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('faculty'); v_id bigint;
begin
  perform public.throw_if_errors(public.validate_trip_fields(p_body, true));
  insert into public.vehicle_requests (requester_id, booking_source, request_date, destination, purpose, trip_date, trip_end_date,
    trip_type, departure_time, estimated_return_time, passengers, number_of_passengers, status)
  values (v_me.id, 'online', now(), p_body ->> 'destination', p_body ->> 'purpose', (p_body ->> 'trip_date')::date,
    (p_body ->> 'trip_end_date')::date, p_body ->> 'trip_type', (p_body ->> 'departure_time')::time,
    (p_body ->> 'estimated_return_time')::time, p_body ->> 'passengers', (p_body ->> 'number_of_passengers')::int, 'pending')
  returning id into v_id;
  perform public.log_action(v_me.id, 'CREATE_VEHICLE_REQUEST', 'vehicle_requests', v_id::text);
  return jsonb_build_object('data', public.res_vehicle_request(v_id));
end $$;

create or replace function public.api_vehicle_request_create_on_site(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); v_errs jsonb; v_id bigint; v_veh bigint; v_drv bigint; f text;
begin
  v_errs := public.validate_trip_fields(p_body, true);
  foreach f in array array['requester_name', 'requester_department', 'requester_contact'] loop
    if coalesce(btrim(p_body ->> f), '') = '' then
      v_errs := public.err_add(v_errs, f, 'The ' || replace(f, '_', ' ') || ' field is required.');
    end if;
  end loop;
  v_veh := public.try_int(p_body ->> 'vehicle_id');
  v_drv := public.try_int(p_body ->> 'driver_id');
  if (v_veh is null) <> (v_drv is null) then
    v_errs := public.err_add(v_errs, case when v_veh is null then 'vehicle_id' else 'driver_id' end,
      'The ' || case when v_veh is null then 'vehicle' else 'driver' end || ' id field is required when ' || case when v_veh is null then 'driver' else 'vehicle' end || ' id is present.');
  end if;
  if v_veh is not null and not exists (select 1 from public.vehicles where id = v_veh) then v_errs := public.err_add(v_errs, 'vehicle_id', 'The selected vehicle id is invalid.'); end if;
  if v_drv is not null and not exists (select 1 from public.drivers where id = v_drv) then v_errs := public.err_add(v_errs, 'driver_id', 'The selected driver id is invalid.'); end if;
  perform public.throw_if_errors(v_errs);

  insert into public.vehicle_requests (requester_id, booking_source, requester_name, requester_department, requester_contact, request_date,
    destination, purpose, trip_date, trip_end_date, trip_type, departure_time, estimated_return_time, passengers, number_of_passengers, status)
  values (null, 'on_site', p_body ->> 'requester_name', p_body ->> 'requester_department', p_body ->> 'requester_contact', now(),
    p_body ->> 'destination', p_body ->> 'purpose', (p_body ->> 'trip_date')::date, (p_body ->> 'trip_end_date')::date,
    p_body ->> 'trip_type', (p_body ->> 'departure_time')::time, (p_body ->> 'estimated_return_time')::time,
    p_body ->> 'passengers', (p_body ->> 'number_of_passengers')::int, 'pending')
  returning id into v_id;

  if v_veh is not null and v_drv is not null then
    perform public.allocate_request(v_id, v_veh, v_drv, v_me.id, null, true);
  end if;

  perform public.log_action(v_me.id, 'CREATE_ON_SITE_BOOKING', 'vehicle_requests', v_id::text);
  return jsonb_build_object('data', public.res_vehicle_request(v_id));
end $$;

create or replace function public.api_vehicle_request_status(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); r public.vehicle_requests; v_ok boolean;
begin
  select * into r from public.vehicle_requests where id = p_id;
  if r.id is null then perform public.fail(404, 'No query results for model [App\Models\VehicleRequest] ' || p_id); end if;
  if r.status <> 'pending' then perform public.fail(403, 'This action is unauthorized.'); end if;
  if coalesce(p_body ->> 'status', '') not in ('approved', 'disapproved') then
    perform public.fail_validation('status', 'The selected status is invalid.');
  end if;
  v_ok := p_body ->> 'status' = 'approved';
  if not v_ok and coalesce(btrim(p_body ->> 'remarks'), '') = '' then
    perform public.fail_validation('remarks', 'Please provide a reason for disapproval.');
  end if;
  update public.vehicle_requests
    set status = p_body ->> 'status',
        disapproval_reason = case when v_ok then null else p_body ->> 'remarks' end,
        approved_by = v_me.id,
        approved_date = case when v_ok then now() else null end
    where id = p_id;
  perform public.log_action(v_me.id, 'UPDATE_VEHICLE_REQUEST_STATUS', 'vehicle_requests', p_id::text);
  return jsonb_build_object('data', public.res_vehicle_request(p_id));
end $$;

create or replace function public.api_vehicle_request_edit(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('faculty'); r public.vehicle_requests; t public.trips; v_errs jsonb; v_was_approved boolean;
begin
  select * into r from public.vehicle_requests where id = p_id;
  if r.id is null then perform public.fail(404, 'No query results for model [App\Models\VehicleRequest] ' || p_id); end if;
  if r.requester_id is distinct from v_me.id or r.status not in ('pending', 'approved') then
    perform public.fail(403, 'This action is unauthorized.');
  end if;
  v_was_approved := r.status = 'approved';

  v_errs := public.validate_trip_fields(p_body, false);
  if v_was_approved and coalesce(btrim(p_body ->> 'edit_reason'), '') = '' then
    v_errs := public.err_add(v_errs, 'edit_reason', 'Please give a reason for editing this approved request.');
  end if;
  perform public.throw_if_errors(v_errs);

  select * into t from public.trips where vehicle_request_id = p_id;
  if t.id is not null and t.trip_status <> 'scheduled' then
    perform public.fail(422, 'This request can no longer be edited because its trip is already ' || t.trip_status || '.');
  end if;

  if t.id is not null then
    delete from public.trips where id = t.id;
    perform public.free_vehicle_and_driver(t.vehicle_id, t.driver_id);
  end if;

  update public.vehicle_requests set
    trip_date = (p_body ->> 'trip_date')::date, trip_end_date = (p_body ->> 'trip_end_date')::date,
    trip_type = p_body ->> 'trip_type', departure_time = (p_body ->> 'departure_time')::time,
    destination = p_body ->> 'destination', purpose = p_body ->> 'purpose',
    estimated_return_time = (p_body ->> 'estimated_return_time')::time, passengers = p_body ->> 'passengers',
    number_of_passengers = (p_body ->> 'number_of_passengers')::int,
    edit_reason = case when p_body ? 'edit_reason' then nullif(btrim(p_body ->> 'edit_reason'), '') else edit_reason end,
    status = case when v_was_approved then 'pending' else status end,
    approved_by = case when v_was_approved then null else approved_by end,
    approved_date = case when v_was_approved then null else approved_date end
  where id = p_id;

  perform public.log_action(v_me.id, 'EDIT_VEHICLE_REQUEST', 'vehicle_requests', p_id::text);
  return jsonb_build_object('message', 'Vehicle request updated successfully.', 'data', public.res_vehicle_request(p_id));
end $$;

-- ================= allocations =================

create or replace function public.api_allocation_options(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator', 'staff');
  v_s date := coalesce(public.try_date(p_params ->> 'start_date'), public.app_today());
  v_e date; v_st time := public.try_time(p_params ->> 'start_time'); v_et time := public.try_time(p_params ->> 'end_time');
  v_ign bigint := public.try_int(p_params ->> 'ignore_trip_id'); v_veh jsonb; v_drv jsonb;
begin
  if coalesce(p_params ->> 'skip_completion', '0') not in ('1', 'true') then
    perform public.complete_finished_trips();
  end if;
  v_e := coalesce(public.try_date(p_params ->> 'end_date'), v_s);
  if v_e < v_s then perform public.fail_validation('end_date', 'The end date field must be a date after or equal to start date.'); end if;
  if v_st is not null and v_et is not null and v_et <= v_st then perform public.fail_validation('end_time', 'The end time field must be a time after start time.'); end if;

  select coalesce(jsonb_agg(public.vehicle_option(v.id, (
    select case when bool_or(b.trip_status = 'in_progress') then 'On a trip (in progress)' else 'Has a scheduled trip on this date' end
    from public.busy_trips(v_s, v_e, v_ign, v_st, v_et) b where b.vehicle_id = v.id having count(*) > 0
  )) order by v.plate_number), '[]'::jsonb) into v_veh
  from public.vehicles v where v.is_active and v.status in ('available', 'in_use');

  select coalesce(jsonb_agg(public.driver_option(d.id, coalesce(
    (select case when bool_or(b.trip_status = 'in_progress') then 'On a trip (in progress)' else 'Has a scheduled trip on this date' end
     from public.busy_trips(v_s, v_e, v_ign, v_st, v_et) b where b.driver_id = d.id having count(*) > 0),
    case when not d.is_available and not exists (select 1 from public.trips t where t.driver_id = d.id and t.trip_status in ('scheduled', 'in_progress')) then 'Marked unavailable' end,
    case when d.license_expiry_date < v_e then 'License expires before the trip date' end
  )) order by d.last_name, d.first_name), '[]'::jsonb) into v_drv
  from public.drivers d;

  return jsonb_build_object('vehicles', v_veh, 'drivers', v_drv);
end $$;

create or replace function public.api_allocations_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_auth();
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_per int := least(greatest(coalesce(public.try_int(p_params ->> 'per_page'), 20), 1), 100);
  v_search text := nullif(btrim(coalesce(p_params ->> 'search', '')), '');
  v_all bigint[]; v_ids bigint[];
begin
  if nullif(p_params ->> 'status', '') is not null and (p_params ->> 'status') not in ('scheduled', 'in_progress', 'completed', 'cancelled') then
    perform public.fail_validation('status', 'The selected status is invalid.');
  end if;
  perform public.complete_finished_trips();

  select coalesce(array_agg(a.id order by coalesce(a.updated_at, a.allocation_date, a.created_at) desc, a.allocation_date desc, a.created_at desc, a.id desc), '{}') into v_all
  from public.allocations a
  join public.trips t on t.id = a.trip_id
  join public.vehicle_requests r on r.id = t.vehicle_request_id
  left join public.vehicles v on v.id = a.vehicle_id
  left join public.drivers d on d.id = a.driver_id
  left join public.profiles q on q.id = r.requester_id
  left join public.profiles cb on cb.id = t.cancelled_by
  where (v_me.role <> 'faculty' or r.requester_id = v_me.id)
    and (nullif(p_params ->> 'status', '') is null or t.trip_status = p_params ->> 'status')
    and (v_search is null or concat_ws(chr(1), t.destination, t.purpose, t.cancellation_reason, cb.first_name, cb.last_name,
          v.vehicle_model, v.plate_number, d.first_name, d.last_name, d.contact_number, q.first_name, q.last_name, q.email,
          r.requester_name, r.requester_department, r.requester_contact) ilike '%' || v_search || '%');

  v_ids := v_all[(v_page - 1) * v_per + 1 : v_page * v_per];
  return public.page_result(public.collect('res_allocation', v_ids), v_page, v_per, cardinality(v_all));
end $$;

create or replace function public.api_allocation_store(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator'); v_errs jsonb := '{}'::jsonb;
  v_req bigint := public.try_int(p_body ->> 'vehicle_request_id'); v_veh bigint := public.try_int(p_body ->> 'vehicle_id');
  v_drv bigint := public.try_int(p_body ->> 'driver_id'); r public.vehicle_requests; v_id bigint;
begin
  if v_req is null then v_errs := public.err_add(v_errs, 'vehicle_request_id', 'The vehicle request id field is required.');
  elsif not exists (select 1 from public.vehicle_requests where id = v_req) then v_errs := public.err_add(v_errs, 'vehicle_request_id', 'Vehicle request not found.'); end if;
  if v_veh is null then v_errs := public.err_add(v_errs, 'vehicle_id', 'The vehicle id field is required.');
  elsif not exists (select 1 from public.vehicles where id = v_veh) then v_errs := public.err_add(v_errs, 'vehicle_id', 'Vehicle not found.'); end if;
  if v_drv is null then v_errs := public.err_add(v_errs, 'driver_id', 'The driver id field is required.');
  elsif not exists (select 1 from public.drivers where id = v_drv) then v_errs := public.err_add(v_errs, 'driver_id', 'Driver not found.'); end if;
  if length(coalesce(p_body ->> 'notes', '')) > 500 then v_errs := public.err_add(v_errs, 'notes', 'The notes field must not be greater than 500 characters.'); end if;
  perform public.throw_if_errors(v_errs);

  select * into r from public.vehicle_requests where id = v_req;
  v_id := public.allocate_request(v_req, v_veh, v_drv, v_me.id, p_body ->> 'notes',
    coalesce((p_body ->> 'approve_request')::boolean, false) and r.status = 'pending');
  perform public.log_action(v_me.id, 'APPROVE_AND_ALLOCATE_REQUEST', 'allocations', v_id::text);
  return jsonb_build_object('data', public.res_allocation(v_id));
end $$;

create or replace function public.api_allocation_update(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator'); v_errs jsonb := '{}'::jsonb;
  a public.allocations; t public.trips; v_veh bigint; v_drv bigint; v_status text; v_new date; v_reason text;
  v_vchg boolean; v_dchg boolean; v_schg boolean; v_active boolean; v_datechg boolean; v_old date;
begin
  select * into a from public.allocations where id = p_id;
  if a.id is null then perform public.fail(404, 'No query results for model [App\Models\Allocation] ' || p_id); end if;
  select * into t from public.trips where id = a.trip_id;

  v_veh := coalesce(public.try_int(p_body ->> 'vehicle_id'), a.vehicle_id);
  v_drv := coalesce(public.try_int(p_body ->> 'driver_id'), a.driver_id);
  v_status := coalesce(nullif(p_body ->> 'status', ''), t.trip_status);
  v_new := public.try_date(p_body ->> 'new_date');
  v_reason := nullif(btrim(coalesce(p_body ->> 'reason', '')), '');

  if not exists (select 1 from public.vehicles where id = v_veh) then v_errs := public.err_add(v_errs, 'vehicle_id', 'Vehicle not found.'); end if;
  if not exists (select 1 from public.drivers where id = v_drv) then v_errs := public.err_add(v_errs, 'driver_id', 'Driver not found.'); end if;
  if nullif(p_body ->> 'status', '') is not null and (p_body ->> 'status') not in ('scheduled', 'in_progress', 'completed') then
    v_errs := public.err_add(v_errs, 'status', 'The selected status is invalid.');
  end if;
  if nullif(p_body ->> 'new_date', '') is not null then
    if v_new is null then v_errs := public.err_add(v_errs, 'new_date', 'The new date field must match the format Y-m-d.');
    elsif v_new < public.app_today() then v_errs := public.err_add(v_errs, 'new_date', 'The new date field must be a date after or equal to today.'); end if;
    if v_reason is null then v_errs := public.err_add(v_errs, 'reason', 'Please give a reason for changing the date.'); end if;
  end if;
  perform public.throw_if_errors(v_errs);

  v_vchg := v_veh <> t.vehicle_id;
  v_dchg := v_drv <> t.driver_id;
  v_schg := v_status <> t.trip_status;
  v_active := t.trip_status in ('scheduled', 'in_progress');
  v_datechg := v_new is not null and v_new <> t.trip_date;

  if not v_active and (v_vchg or v_dchg or v_schg or v_datechg) then
    perform public.fail_validation('status', 'This trip is already ' || t.trip_status || ' and can no longer be changed. Create a new request instead.');
  end if;
  if v_datechg and t.trip_status <> 'scheduled' then
    perform public.fail_validation('new_date', 'Only scheduled trips can have their date changed (this trip is ' || t.trip_status || ').');
  end if;

  if v_active and (v_vchg or v_dchg or v_datechg) then
    perform 1 from public.vehicles where id = v_veh for update;
    perform 1 from public.drivers where id = v_drv for update;
    perform public.assert_assignable(t.vehicle_request_id, v_veh, v_drv, t.id, case when v_datechg then v_new end, false);
  end if;

  if v_vchg then
    update public.vehicles set status = 'available' where id = t.vehicle_id;
    update public.vehicles set status = 'in_use' where id = v_veh;
  end if;
  if v_dchg then
    update public.drivers set is_available = true where id = t.driver_id;
    update public.drivers set is_available = false, assigned_vehicle_id = v_veh where id = v_drv;
  elsif v_vchg then
    update public.drivers set assigned_vehicle_id = v_veh where id = v_drv;
  end if;

  update public.trips set vehicle_id = v_veh, driver_id = v_drv, trip_status = v_status where id = t.id;
  update public.allocations set vehicle_id = v_veh, driver_id = v_drv,
    notes = case when p_body ? 'notes' then nullif(p_body ->> 'notes', '') else notes end
    where id = p_id;

  if v_datechg then
    v_old := public.shift_trip_date(t.id, v_new);
    delete from public.reschedule_requests where trip_id = t.id and status = 'pending';
    insert into public.reschedule_requests (trip_id, requested_by, old_date, new_date, reason, status, handled_by, handled_at)
    values (t.id, v_me.id, v_old, v_new, v_reason, 'approved', v_me.id, now());
  end if;

  if v_status = 'completed' then
    update public.vehicles set status = 'available' where id = v_veh;
    update public.drivers set is_available = true where id = v_drv;
  end if;

  perform public.log_action(v_me.id, 'UPDATE_ALLOCATION', 'allocations', p_id::text);
  return jsonb_build_object('data', public.res_allocation(p_id));
end $$;

create or replace function public.api_allocation_cancel(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); a public.allocations; t public.trips; v_reason text := nullif(btrim(coalesce(p_body ->> 'reason', '')), '');
begin
  if v_reason is null then perform public.fail_validation('reason', 'The reason field is required.'); end if;
  if length(v_reason) > 500 then perform public.fail_validation('reason', 'The reason field must not be greater than 500 characters.'); end if;
  select * into a from public.allocations where id = p_id;
  if a.id is null then perform public.fail(404, 'No query results for model [App\Models\Allocation] ' || p_id); end if;

  perform public.complete_finished_trips();
  select * into t from public.trips where id = a.trip_id for update;
  if t.trip_status <> 'scheduled' then
    perform public.fail_validation('status', 'Only scheduled trips can be cancelled.');
  end if;

  update public.trips set trip_status = 'cancelled', cancellation_reason = v_reason, cancelled_by = v_me.id, cancelled_at = now() where id = t.id;
  perform public.free_vehicle_and_driver(t.vehicle_id, t.driver_id);

  perform public.log_action(v_me.id, 'CANCEL_TRIP', 'allocations', p_id::text);
  return jsonb_build_object('data', public.res_allocation(p_id));
end $$;

create or replace function public.api_allocation_print_data(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff');
  a public.allocations; t public.trips; r public.vehicle_requests; q public.profiles; v public.vehicles; d public.drivers; cb public.profiles;
begin
  select * into a from public.allocations where id = p_id;
  if a.id is null then perform public.fail(404, 'No query results for model [App\Models\Allocation] ' || p_id); end if;
  select * into t from public.trips where id = a.trip_id;
  select * into r from public.vehicle_requests where id = t.vehicle_request_id;
  select * into q from public.profiles where id = r.requester_id;
  select * into v from public.vehicles where id = a.vehicle_id;
  select * into d from public.drivers where id = a.driver_id;
  select * into cb from public.profiles where id = t.cancelled_by;

  if r.id is null or r.status <> 'approved' or v.id is null or d.id is null then
    perform public.fail(422, 'Only approved requests with a vehicle and driver assigned can be printed.');
  end if;

  return jsonb_build_object(
    'ruvNumber', public.ensure_ruv_number(p_id),
    'requestNo', r.id,
    'official', upper(coalesce(nullif(r.requester_name, ''), public.full_name(q.first_name, q.last_name))),
    'position', coalesce(r.requester_department, q."position", ''),
    'destination', r.destination, 'purpose', r.purpose, 'passengers', r.passengers,
    'travelDate', case when r.trip_end_date = r.trip_date then to_char(r.trip_date, 'FMMonth FMDD, YYYY')
                       else to_char(r.trip_date, 'FMMonth FMDD, YYYY') || ' to ' || to_char(r.trip_end_date, 'FMMonth FMDD, YYYY') end,
    'days', (r.trip_end_date - r.trip_date) + 1, 'tripType', r.trip_type,
    'departure', to_char(r.departure_time, 'FMHH12:MI AM'),
    'dateRequested', to_char(r.request_date at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY'),
    'timeRequested', to_char(r.request_date at time zone 'Asia/Manila', 'FMHH12:MI AM'),
    'plateNumber', v.plate_number, 'driverName', public.full_name(d.first_name, d.last_name),
    'isCancelled', t.trip_status = 'cancelled', 'cancellationReason', t.cancellation_reason,
    'cancelledBy', public.full_name(cb.first_name, cb.last_name),
    'cancelledAt', to_char(t.cancelled_at at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY FMHH12:MI AM')
  );
end $$;

-- ================= quick add =================

create or replace function public.api_create_driver(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); v_errs jsonb := '{}'::jsonb; v_parts text[]; v_last text; v_first text; v_id bigint;
begin
  if coalesce(btrim(p_body ->> 'name'), '') = '' then v_errs := public.err_add(v_errs, 'name', 'The name field is required.');
  elsif length(p_body ->> 'name') > 120 then v_errs := public.err_add(v_errs, 'name', 'The name field must not be greater than 120 characters.'); end if;
  if coalesce(p_body ->> 'contact_number', '') = '' then v_errs := public.err_add(v_errs, 'contact_number', 'The contact number field is required.');
  elsif (p_body ->> 'contact_number') !~ '^09[0-9]{9}$' then v_errs := public.err_add(v_errs, 'contact_number', 'The contact number field format is invalid.'); end if;
  if coalesce(btrim(p_body ->> 'license_number'), '') = '' then v_errs := public.err_add(v_errs, 'license_number', 'The license number field is required.');
  elsif exists (select 1 from public.drivers where license_number = p_body ->> 'license_number') then v_errs := public.err_add(v_errs, 'license_number', 'The license number has already been taken.'); end if;
  if public.try_date(p_body ->> 'license_expiry_date') is null then v_errs := public.err_add(v_errs, 'license_expiry_date', 'The license expiry date field must match the format Y-m-d.'); end if;
  perform public.throw_if_errors(v_errs);

  v_parts := regexp_split_to_array(btrim(p_body ->> 'name'), '\s+');
  v_last := v_parts[array_length(v_parts, 1)];
  v_first := case when array_length(v_parts, 1) > 1 then array_to_string(v_parts[1 : array_length(v_parts, 1) - 1], ' ') else v_parts[1] end;

  insert into public.drivers (first_name, last_name, contact_number, license_number, license_expiry_date, is_available)
  values (v_first, v_last, p_body ->> 'contact_number', p_body ->> 'license_number', (p_body ->> 'license_expiry_date')::date, true)
  returning id into v_id;
  perform public.log_action(v_me.id, 'CREATE_DRIVER', 'drivers', v_id::text);
  return jsonb_build_object('data', public.driver_option(v_id));
end $$;

create or replace function public.api_create_vehicle(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); v_errs jsonb := '{}'::jsonb; v_cap int := public.try_int(p_body ->> 'capacity'); v_id bigint;
begin
  if coalesce(btrim(p_body ->> 'plate_number'), '') = '' then v_errs := public.err_add(v_errs, 'plate_number', 'The plate number field is required.');
  elsif length(p_body ->> 'plate_number') > 20 then v_errs := public.err_add(v_errs, 'plate_number', 'The plate number field must not be greater than 20 characters.');
  elsif exists (select 1 from public.vehicles where plate_number = p_body ->> 'plate_number') then v_errs := public.err_add(v_errs, 'plate_number', 'The plate number has already been taken.'); end if;
  if coalesce(btrim(p_body ->> 'vehicle_model'), '') = '' then v_errs := public.err_add(v_errs, 'vehicle_model', 'The vehicle model field is required.');
  elsif length(p_body ->> 'vehicle_model') > 100 then v_errs := public.err_add(v_errs, 'vehicle_model', 'The vehicle model field must not be greater than 100 characters.'); end if;
  if v_cap is null then v_errs := public.err_add(v_errs, 'capacity', 'The capacity field is required.');
  elsif v_cap < 1 or v_cap > 100 then v_errs := public.err_add(v_errs, 'capacity', 'The capacity field must be between 1 and 100.'); end if;
  perform public.throw_if_errors(v_errs);

  insert into public.vehicles (plate_number, vehicle_model, vehicle_type, capacity, status, is_active)
  values (p_body ->> 'plate_number', p_body ->> 'vehicle_model', coalesce(nullif(p_body ->> 'vehicle_type', ''), 'Not specified'), v_cap, 'available', true)
  returning id into v_id;
  perform public.log_action(v_me.id, 'CREATE_VEHICLE', 'vehicles', v_id::text);
  return jsonb_build_object('data', public.vehicle_option(v_id));
end $$;

-- ================= date changes =================

create or replace function public.api_reschedule_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_auth(); v_ids bigint[];
begin
  select coalesce(array_agg(x.id order by x.created_at desc, x.id desc), '{}') into v_ids from (
    select r.id, r.created_at from public.reschedule_requests r
    join public.trips t on t.id = r.trip_id
    join public.vehicle_requests vr on vr.id = t.vehicle_request_id
    where (v_me.role <> 'faculty' or vr.requester_id = v_me.id)
      and (nullif(p_params ->> 'status', '') is null or r.status = p_params ->> 'status')
    order by r.created_at desc, r.id desc limit 100
  ) x;
  return jsonb_build_object('data', public.collect('res_reschedule', v_ids));
end $$;

create or replace function public.api_reschedule_request_create(p_allocation bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('faculty'); t public.trips; r public.vehicle_requests; v_new date := public.try_date(p_body ->> 'new_date'); v_reason text := nullif(btrim(coalesce(p_body ->> 'reason', '')), ''); v_errs jsonb := '{}'::jsonb; v_id bigint;
begin
  select tr.* into t from public.allocations a join public.trips tr on tr.id = a.trip_id where a.id = p_allocation;
  if t.id is null then perform public.fail(404, 'No query results for model [App\Models\Allocation] ' || p_allocation); end if;
  select * into r from public.vehicle_requests where id = t.vehicle_request_id;
  if r.requester_id is distinct from v_me.id then perform public.fail(403, 'You may only request a date change for your own trips.'); end if;

  if v_new is null then v_errs := public.err_add(v_errs, 'new_date', 'The new date field must match the format Y-m-d.');
  elsif v_new < public.app_today() then v_errs := public.err_add(v_errs, 'new_date', 'The new date field must be a date after or equal to today.'); end if;
  if v_reason is null then v_errs := public.err_add(v_errs, 'reason', 'The reason field is required.');
  elsif length(v_reason) > 500 then v_errs := public.err_add(v_errs, 'reason', 'The reason field must not be greater than 500 characters.'); end if;
  perform public.throw_if_errors(v_errs);

  if t.trip_status <> 'scheduled' then perform public.fail(422, 'A ' || t.trip_status || ' trip can no longer be rescheduled.'); end if;
  if exists (select 1 from public.reschedule_requests where trip_id = t.id and status = 'pending') then perform public.fail(422, 'This trip already has a pending date change request.'); end if;
  if v_new = t.trip_date then perform public.fail(422, 'The new date is the same as the current date.'); end if;

  insert into public.reschedule_requests (trip_id, requested_by, old_date, new_date, reason, status)
  values (t.id, v_me.id, t.trip_date, v_new, v_reason, 'pending') returning id into v_id;
  perform public.log_action(v_me.id, 'CREATE_RESCHEDULE_REQUEST', 'reschedule_requests', v_id::text);
  return jsonb_build_object('data', public.res_reschedule(v_id));
end $$;

create or replace function public.api_reschedule_approve(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); r public.reschedule_requests;
begin
  select * into r from public.reschedule_requests where id = p_id;
  if r.id is null then perform public.fail(404, 'No query results for model [App\Models\RescheduleRequest] ' || p_id); end if;
  if r.status <> 'pending' then perform public.fail(422, 'This request is already ' || r.status || '.'); end if;
  if length(coalesce(p_body ->> 'admin_reason', '')) > 500 then perform public.fail_validation('admin_reason', 'The admin reason field must not be greater than 500 characters.'); end if;

  perform public.move_trip(r.trip_id, r.new_date);
  update public.reschedule_requests set status = 'approved', handled_by = v_me.id, handled_at = now(), admin_reason = nullif(p_body ->> 'admin_reason', '') where id = p_id;
  perform public.log_action(v_me.id, 'APPROVE_RESCHEDULE_REQUEST', 'reschedule_requests', p_id::text);
  return jsonb_build_object('data', public.res_reschedule(p_id));
end $$;

create or replace function public.api_reschedule_disapprove(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); r public.reschedule_requests; v_reason text := nullif(btrim(coalesce(p_body ->> 'admin_reason', '')), '');
begin
  select * into r from public.reschedule_requests where id = p_id;
  if r.id is null then perform public.fail(404, 'No query results for model [App\Models\RescheduleRequest] ' || p_id); end if;
  if r.status <> 'pending' then perform public.fail(422, 'This request is already ' || r.status || '.'); end if;
  if v_reason is null then perform public.fail_validation('admin_reason', 'The admin reason field is required.'); end if;
  if length(v_reason) > 500 then perform public.fail_validation('admin_reason', 'The admin reason field must not be greater than 500 characters.'); end if;

  update public.reschedule_requests set status = 'disapproved', handled_by = v_me.id, handled_at = now(), admin_reason = v_reason where id = p_id;
  perform public.log_action(v_me.id, 'DISAPPROVE_RESCHEDULE_REQUEST', 'reschedule_requests', p_id::text);
  return jsonb_build_object('data', public.res_reschedule(p_id));
end $$;

create or replace function public.api_reschedule_direct(p_allocation bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); t public.trips; v_new date := public.try_date(p_body ->> 'new_date'); v_reason text := nullif(btrim(coalesce(p_body ->> 'reason', '')), ''); v_errs jsonb := '{}'::jsonb; v_old date; v_id bigint;
begin
  if v_new is null then v_errs := public.err_add(v_errs, 'new_date', 'The new date field must match the format Y-m-d.');
  elsif v_new < public.app_today() then v_errs := public.err_add(v_errs, 'new_date', 'The new date field must be a date after or equal to today.'); end if;
  if v_reason is null then v_errs := public.err_add(v_errs, 'reason', 'The reason field is required.'); end if;
  perform public.throw_if_errors(v_errs);

  select tr.* into t from public.allocations a join public.trips tr on tr.id = a.trip_id where a.id = p_allocation;
  if t.id is null then perform public.fail(404, 'No query results for model [App\Models\Allocation] ' || p_allocation); end if;

  v_old := public.move_trip(t.id, v_new);
  delete from public.reschedule_requests where trip_id = t.id and status = 'pending';
  insert into public.reschedule_requests (trip_id, requested_by, old_date, new_date, reason, status, handled_by, handled_at)
  values (t.id, v_me.id, v_old, v_new, v_reason, 'approved', v_me.id, now()) returning id into v_id;
  perform public.log_action(v_me.id, 'RESCHEDULE_ALLOCATION', 'allocations', p_allocation::text);
  return jsonb_build_object('data', public.res_reschedule(v_id));
end $$;

-- ================= sharing a trip request =================

create or replace function public.api_admins() returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff');
begin
  return jsonb_build_object('data', coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'name', public.full_name(p.first_name, p.last_name), 'email', p.email) order by p.email)
    from public.profiles p where p.role = 'administrator' and p.is_active and p.id <> v_me.id
  ), '[]'::jsonb));
end $$;

create or replace function public.api_trip_shares_list() returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff'); v_ids bigint[];
begin
  select coalesce(array_agg(x.id order by x.created_at desc, x.id desc), '{}') into v_ids from (
    select id, created_at from public.trip_request_shares where recipient_id = v_me.id order by created_at desc, id desc limit 100) x;
  return jsonb_build_object('data', public.collect('res_share', v_ids));
end $$;

create or replace function public.api_trip_share_create(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff'); v_alloc bigint := public.try_int(p_body ->> 'allocation_id'); v_rec bigint := public.try_int(p_body ->> 'recipient_id'); v_errs jsonb := '{}'::jsonb; v_id bigint;
begin
  if v_alloc is null or not exists (select 1 from public.allocations where id = v_alloc) then v_errs := public.err_add(v_errs, 'allocation_id', 'The selected allocation id is invalid.'); end if;
  if v_rec is null or not exists (select 1 from public.profiles where id = v_rec and role = 'administrator') then v_errs := public.err_add(v_errs, 'recipient_id', 'The selected recipient id is invalid.'); end if;
  perform public.throw_if_errors(v_errs);
  if v_rec = v_me.id then perform public.fail(422, 'Choose another admin.'); end if;

  insert into public.trip_request_shares (allocation_id, sender_id, recipient_id) values (v_alloc, v_me.id, v_rec) returning id into v_id;
  perform public.log_action(v_me.id, 'SEND_TRIP_REQUEST', 'trip_request_shares', v_id::text);
  return jsonb_build_object('data', public.res_share(v_id));
end $$;

-- ================= trips =================

create or replace function public.api_trips_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator', 'staff');
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_per int := public.try_int(p_params ->> 'per_page');
  v_search text := nullif(btrim(coalesce(p_params ->> 'search', '')), '');
  v_all bigint[]; v_ids bigint[];
begin
  if nullif(p_params ->> 'status', '') is not null and (p_params ->> 'status') not in ('scheduled', 'in_progress', 'completed', 'cancelled') then
    perform public.fail_validation('status', 'The selected status is invalid.');
  end if;
  if nullif(p_params ->> 'trip_type', '') is not null and (p_params ->> 'trip_type') not in ('inclusive', 'exclusive') then
    perform public.fail_validation('trip_type', 'The selected trip type is invalid.');
  end if;
  perform public.complete_finished_trips();

  select coalesce(array_agg(t.id order by t.trip_date, t.departure_time, t.id), '{}') into v_all
  from public.trips t
  left join public.vehicle_requests r on r.id = t.vehicle_request_id
  left join public.vehicles v on v.id = t.vehicle_id
  left join public.drivers d on d.id = t.driver_id
  left join public.profiles q on q.id = r.requester_id
  left join public.profiles cb on cb.id = t.cancelled_by
  where (case when nullif(p_params ->> 'status', '') is not null then t.trip_status = p_params ->> 'status' else t.trip_status in ('scheduled', 'in_progress') end)
    and (nullif(p_params ->> 'trip_type', '') is null or r.trip_type = p_params ->> 'trip_type')
    and (nullif(p_params ->> 'month', '') is null or extract(month from t.trip_date) = public.try_int(p_params ->> 'month'))
    and (nullif(p_params ->> 'year', '') is null or extract(year from t.trip_date) = public.try_int(p_params ->> 'year'))
    and (v_search is null or concat_ws(chr(1), t.destination, t.purpose, t.cancellation_reason, cb.first_name, cb.last_name,
          v.vehicle_model, v.plate_number, d.first_name, d.last_name, q.first_name, q.last_name,
          r.requester_name, r.requester_department, r.requester_contact) ilike '%' || v_search || '%');

  if v_per is null then
    return jsonb_build_object('data', public.collect('res_trip', v_all));
  end if;
  v_per := least(greatest(v_per, 1), 100);
  v_ids := v_all[(v_page - 1) * v_per + 1 : v_page * v_per];
  return public.page_result(public.collect('res_trip', v_ids), v_page, v_per, cardinality(v_all));
end $$;

create or replace function public.api_my_trips(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('faculty');
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_search text := nullif(btrim(coalesce(p_params ->> 'search', '')), '');
  v_all bigint[]; v_ids bigint[];
begin
  if nullif(p_params ->> 'status', '') is not null and (p_params ->> 'status') not in ('scheduled', 'in_progress', 'completed') then
    perform public.fail_validation('status', 'The selected status is invalid.');
  end if;
  perform public.complete_finished_trips();

  select coalesce(array_agg(t.id order by t.trip_date, t.departure_time, t.id), '{}') into v_all
  from public.trips t
  join public.vehicle_requests r on r.id = t.vehicle_request_id
  left join public.vehicles v on v.id = t.vehicle_id
  left join public.drivers d on d.id = t.driver_id
  where r.requester_id = v_me.id
    and t.trip_status in ('scheduled', 'in_progress', 'completed')
    and (nullif(p_params ->> 'status', '') is null or t.trip_status = p_params ->> 'status')
    and (nullif(p_params ->> 'trip_type', '') is null or r.trip_type = p_params ->> 'trip_type')
    and (nullif(p_params ->> 'month', '') is null or extract(month from t.trip_date) = public.try_int(p_params ->> 'month'))
    and (nullif(p_params ->> 'year', '') is null or extract(year from t.trip_date) = public.try_int(p_params ->> 'year'))
    and (v_search is null or concat_ws(chr(1), t.destination, t.purpose, v.vehicle_model, v.plate_number, d.first_name, d.last_name) ilike '%' || v_search || '%');

  v_ids := v_all[(v_page - 1) * 10 + 1 : v_page * 10];
  return public.page_result(public.collect('res_trip', v_ids), v_page, 10, cardinality(v_all));
end $$;

create or replace function public.api_trip_views_list() returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff');
begin
  return jsonb_build_object('trip_ids', coalesce((select jsonb_agg(trip_id order by trip_id) from public.trip_views where user_id = v_me.id), '[]'::jsonb));
end $$;

create or replace function public.api_trip_view_store(p_trip bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff');
begin
  if not exists (select 1 from public.trips where id = p_trip) then perform public.fail(404, 'No query results for model [App\Models\Trip] ' || p_trip); end if;
  insert into public.trip_views (user_id, trip_id) values (v_me.id, p_trip) on conflict (user_id, trip_id) do nothing;
  perform public.log_action(v_me.id, 'VIEW_TRIP_DETAILS', 'trips', p_trip::text);
  return jsonb_build_object('trip_id', p_trip, 'viewed', true);
end $$;

create or replace function public.api_vehicles_list() returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator', 'staff');
begin
  return jsonb_build_object('data', coalesce((select jsonb_agg(public.res_vehicle(v.id) order by v.plate_number) from public.vehicles v), '[]'::jsonb));
end $$;