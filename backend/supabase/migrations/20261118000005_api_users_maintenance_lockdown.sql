set check_function_bodies = off;

-- ================= users =================

create or replace function public.api_users_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator');
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_terms text[] := case when coalesce(btrim(p_params ->> 'search'), '') = '' then null else regexp_split_to_array(btrim(p_params ->> 'search'), '\s+') end;
  v_all bigint[]; v_ids bigint[];
begin
  if nullif(p_params ->> 'role', '') is not null and (p_params ->> 'role') not in ('administrator', 'faculty', 'staff') then
    perform public.fail_validation('role', 'The selected role is invalid.');
  end if;

  select coalesce(array_agg(p.id order by (p.deletion_requested_at is not null), p.last_name, p.first_name, p.id), '{}') into v_all
  from public.profiles p
  where (nullif(p_params ->> 'role', '') is null or p.role = p_params ->> 'role')
    and (coalesce(p_params ->> 'deletion_status', '') <> 'pending' or p.deletion_requested_at is not null)
    and (v_terms is null or not exists (
      select 1 from unnest(v_terms) t where not (
        concat_ws(chr(1), p.first_name, p.last_name, p.email, p."position", p.phone_number) ilike '%' || t || '%'
        or p.role ilike '%' || case when position(lower(t) in 'user') > 0 then 'faculty' else t end || '%'
      )
    ));

  v_ids := v_all[(v_page - 1) * 10 + 1 : v_page * 10];
  return public.page_result(public.collect('res_user', v_ids), v_page, 10, cardinality(v_all));
end $$;

create or replace function public.api_user_request_deletion(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); u public.profiles;
begin
  select * into u from public.profiles where id = p_id;
  if u.id is null then perform public.fail(404, 'No query results for model [App\Models\User] ' || p_id); end if;
  if u.role = 'administrator' then perform public.fail(422, 'Administrator accounts cannot be deleted.'); end if;
  if u.deletion_requested_at is not null then perform public.fail(422, 'This account is already pending deletion.'); end if;
  if u.id = v_me.id then perform public.fail(422, 'You cannot schedule your own account for deletion.'); end if;

  update public.profiles set deletion_requested_at = now(), is_active = false where id = p_id;
  begin
    delete from auth.sessions where user_id = u.auth_id;
  exception when others then
    null; -- the account is already blocked by is_active
  end;
  perform public.log_action(v_me.id, 'DEACTIVATE_USER', 'users', p_id::text);
  return jsonb_build_object(
    'message', 'Account deactivated. Personal details are scheduled to be anonymized after 30 days; the account record and historical references will remain. The account can be restored during this period.',
    'user', public.res_user(p_id)
  );
end $$;

create or replace function public.api_user_cancel_deletion(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); u public.profiles;
begin
  select * into u from public.profiles where id = p_id;
  if u.id is null then perform public.fail(404, 'No query results for model [App\Models\User] ' || p_id); end if;
  if u.deletion_requested_at is null then perform public.fail(422, 'This account is not pending deletion.'); end if;
  if u.deletion_requested_at + interval '30 days' <= now() then perform public.fail(422, 'The 30-day deletion period has expired.'); end if;

  update public.profiles set deletion_requested_at = null, is_active = true where id = p_id;
  perform public.log_action(v_me.id, 'RESTORE_USER', 'users', p_id::text);
  return jsonb_build_object('data', public.res_user(p_id));
end $$;

-- Used only by the admin-users Edge Function (service role)
create or replace function public.svc_create_profile(p_auth_id uuid, p_data jsonb, p_actor bigint, p_ip text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_n int; v_id bigint;
begin
  if p_data ->> 'role' = 'administrator' then
    select count(*) into v_n from (select 1 from public.profiles where role = 'administrator' and is_active for update) s;
    if v_n >= 2 then perform public.fail(400, 'Maximum limit of 2 administrators reached.'); end if;
  end if;
  insert into public.profiles (auth_id, email, first_name, last_name, "position", phone_number, role)
  values (p_auth_id, lower(p_data ->> 'email'), p_data ->> 'first_name', p_data ->> 'last_name',
          nullif(p_data ->> 'position', ''), nullif(p_data ->> 'phone_number', ''), p_data ->> 'role')
  returning id into v_id;
  perform public.log_action(p_actor, 'CREATE_USER', 'users', v_id::text, p_ip);
  return jsonb_build_object('data', public.res_user(v_id), 'message', 'User registered successfully');
end $$;

create or replace function public.svc_admin_transfer(p_auth_id uuid, p_data jsonb, p_actor bigint, p_ip text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_n int; v_has boolean; v_id bigint; v_old uuid;
begin
  select count(*), bool_or(id = p_actor) into v_n, v_has
  from (select id from public.profiles where role = 'administrator' and is_active for update) s;
  if v_n <> 2 or not coalesce(v_has, false) then
    perform public.fail(409, 'Administrator replacement requires exactly two active administrators, including your account.');
  end if;

  insert into public.profiles (auth_id, email, first_name, last_name, "position", phone_number, role, is_active)
  values (p_auth_id, lower(p_data ->> 'email'), p_data ->> 'first_name', p_data ->> 'last_name',
          nullif(p_data ->> 'position', ''), nullif(p_data ->> 'phone_number', ''), 'administrator', true)
  returning id into v_id;

  select auth_id into v_old from public.profiles where id = p_actor;
  update public.profiles set is_active = false where id = p_actor;
  begin
    delete from auth.sessions where user_id = v_old;
  exception when others then
    null;
  end;

  perform public.log_action(p_actor, 'TRANSFER_ADMINISTRATOR', 'users', v_id::text, p_ip);
  return jsonb_build_object('data', public.res_user(v_id), 'message', 'Administrator transfer completed. Sign in with the replacement account.');
end $$;

create or replace function public.svc_update_profile(p_id bigint, p_data jsonb, p_actor bigint, p_ip text default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare u public.profiles; v_errs jsonb := '{}'::jsonb; v_n int; f text;
begin
  select * into u from public.profiles where id = p_id;
  if u.id is null then perform public.fail(404, 'No query results for model [App\Models\User] ' || p_id); end if;

  foreach f in array array['first_name', 'last_name', 'email', 'role'] loop
    if coalesce(btrim(p_data ->> f), '') = '' then v_errs := public.err_add(v_errs, f, 'The ' || replace(f, '_', ' ') || ' field is required.'); end if;
  end loop;
  if coalesce(p_data ->> 'email', '') <> '' then
    if (p_data ->> 'email') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then v_errs := public.err_add(v_errs, 'email', 'The email field must be a valid email address.');
    elsif exists (select 1 from public.profiles where lower(email) = lower(p_data ->> 'email') and id <> p_id) then v_errs := public.err_add(v_errs, 'email', 'The email has already been taken.'); end if;
  end if;
  if coalesce(p_data ->> 'role', '') <> '' and (p_data ->> 'role') not in ('administrator', 'faculty', 'staff') then v_errs := public.err_add(v_errs, 'role', 'The selected role is invalid.'); end if;
  if length(coalesce(p_data ->> 'phone_number', '')) > 20 then v_errs := public.err_add(v_errs, 'phone_number', 'The phone number field must not be greater than 20 characters.'); end if;
  perform public.throw_if_errors(v_errs);

  if u.role = 'administrator' and p_data ->> 'role' <> 'administrator' then
    perform public.fail(422, 'Administrator accounts must keep the Administrator role.');
  end if;

  if u.is_active and u.role <> 'administrator' and p_data ->> 'role' = 'administrator' then
    select count(*) into v_n from (select 1 from public.profiles where role = 'administrator' and is_active for update) s;
    if v_n >= 2 then perform public.fail(400, 'Maximum limit of 2 administrators reached.'); end if;
  end if;

  update public.profiles set
    first_name = p_data ->> 'first_name', last_name = p_data ->> 'last_name', email = lower(p_data ->> 'email'),
    "position" = nullif(p_data ->> 'position', ''), phone_number = nullif(p_data ->> 'phone_number', ''), role = p_data ->> 'role'
  where id = p_id;
  perform public.log_action(p_actor, 'UPDATE_USER', 'users', p_id::text, p_ip);
  return jsonb_build_object('data', public.res_user(p_id));
end $$;

-- ================= audit log =================

create or replace function public.api_audit_logs(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator');
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_per int := least(greatest(coalesce(public.try_int(p_params ->> 'per_page'), 20), 1), 100);
  v_all bigint[]; v_ids bigint[];
begin
  select coalesce(array_agg(l.id order by l.created_at desc, l.id desc), '{}') into v_all
  from public.audit_logs l left join public.profiles u on u.id = l.user_id
  where (nullif(p_params ->> 'action', '') is null or l.action = p_params ->> 'action')
    and (nullif(p_params ->> 'user_email', '') is null or u.email ilike '%' || (p_params ->> 'user_email') || '%');
  v_ids := v_all[(v_page - 1) * v_per + 1 : v_page * v_per];
  return public.page_result(public.collect('res_audit', v_ids), v_page, v_per, cardinality(v_all));
end $$;

-- ================= maintenance =================

create or replace function public.sync_vehicle_dates(p_log bigint) returns void language plpgsql as $$
declare m public.vehicle_maintenance; v_latest bigint;
begin
  select * into m from public.vehicle_maintenance where id = p_log;
  select id into v_latest from public.vehicle_maintenance where vehicle_id = m.vehicle_id order by maintenance_date desc, id desc limit 1;
  if v_latest = p_log then
    update public.vehicles set last_maintenance_date = coalesce(m.completion_date, m.maintenance_date), next_maintenance_date = m.next_due_date where id = m.vehicle_id;
  end if;
end $$;

create or replace function public.restore_vehicle_availability(p_log bigint) returns void language plpgsql as $$
declare m public.vehicle_maintenance;
begin
  select * into m from public.vehicle_maintenance where id = p_log;
  if exists (select 1 from public.vehicles where id = m.vehicle_id and status = 'maintenance')
     and not exists (select 1 from public.vehicle_maintenance where vehicle_id = m.vehicle_id and status = 'in_progress') then
    update public.vehicles set status = 'available' where id = m.vehicle_id;
  end if;
end $$;

create or replace function public.api_maintenance_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator');
  v_today date := public.app_today();
  v_page int := greatest(coalesce(public.try_int(p_params ->> 'page'), 1), 1);
  v_per int := least(greatest(coalesce(public.try_int(p_params ->> 'per_page'), 10), 1), 100);
  v_search text := nullif(btrim(coalesce(p_params ->> 'search', '')), '');
  v_status text := nullif(p_params ->> 'status', '');
  v_all bigint[]; v_ids bigint[]; v_summary jsonb;
begin
  select coalesce(array_agg(m.id order by
      case when m.status = 'in_progress' then 0 when m.status = 'scheduled' and m.maintenance_date >= v_today then 1
           when m.status = 'scheduled' then 2 when m.status = 'cancelled' then 3 when m.status = 'completed' then 4 else 5 end,
      case when m.status in ('cancelled', 'completed') then m.maintenance_date end desc nulls last,
      m.maintenance_date, m.id), '{}') into v_all
  from public.vehicle_maintenance m join public.vehicles v on v.id = m.vehicle_id
  where (nullif(p_params ->> 'vehicle_id', '') is null or m.vehicle_id = public.try_int(p_params ->> 'vehicle_id'))
    and (nullif(p_params ->> 'type', '') is null or m.maintenance_type = p_params ->> 'type')
    and (v_status is null
         or (v_status = 'upcoming' and m.status = 'scheduled' and m.maintenance_date >= v_today)
         or (v_status = 'overdue' and m.status = 'scheduled' and m.maintenance_date < v_today)
         or (v_status not in ('upcoming', 'overdue') and m.status = v_status))
    and (v_search is null or concat_ws(chr(1), m.description, m.maintenance_type, v.plate_number, v.vehicle_model) ilike '%' || v_search || '%')
    and (nullif(p_params ->> 'year', '') is null or extract(year from m.maintenance_date) = public.try_int(p_params ->> 'year'))
    and (nullif(p_params ->> 'month', '') is null or extract(month from m.maintenance_date) = public.try_int(p_params ->> 'month'));

  v_summary := jsonb_build_object(
    'total', (select count(*) from public.vehicle_maintenance),
    'this_month', (select count(*) from public.vehicle_maintenance where extract(year from maintenance_date) = extract(year from v_today) and extract(month from maintenance_date) = extract(month from v_today)),
    'upcoming', (select count(*) from public.vehicle_maintenance where status = 'scheduled' and maintenance_date >= v_today),
    'overdue', (select count(*) from public.vehicle_maintenance where status = 'scheduled' and maintenance_date < v_today)
  );

  v_ids := v_all[(v_page - 1) * v_per + 1 : v_page * v_per];
  return public.page_result(public.collect('res_maintenance', v_ids), v_page, v_per, cardinality(v_all)) || jsonb_build_object('summary', v_summary);
end $$;

create or replace function public.api_maintenance_create(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator'); b jsonb := public.strip_empty(p_body); v_errs jsonb := '{}'::jsonb;
  v_date date := public.try_date(b ->> 'date_performed'); v_next date := public.try_date(b ->> 'next_due_date');
  v_status text := coalesce(b ->> 'status', 'scheduled'); v_id bigint;
begin
  if public.try_int(b ->> 'vehicle_id') is null or not exists (select 1 from public.vehicles where id = public.try_int(b ->> 'vehicle_id')) then v_errs := public.err_add(v_errs, 'vehicle_id', 'The selected vehicle id is invalid.'); end if;
  if coalesce(b ->> 'type', '') not in ('oil_change', 'repair', 'refueling', 'inspection', 'tire_service', 'other') then v_errs := public.err_add(v_errs, 'type', 'The selected type is invalid.'); end if;
  if v_date is null then v_errs := public.err_add(v_errs, 'date_performed', 'The date performed field is required.'); end if;
  if b ? 'next_due_date' and (v_next is null or (v_date is not null and v_next < v_date)) then v_errs := public.err_add(v_errs, 'next_due_date', 'The next due date field must be a date after or equal to date performed.'); end if;
  if v_status not in ('scheduled', 'in_progress', 'completed', 'cancelled') then v_errs := public.err_add(v_errs, 'status', 'The selected status is invalid.'); end if;
  if coalesce(b ->> 'maintenance_category', 'preventive') not in ('preventive', 'corrective') then v_errs := public.err_add(v_errs, 'maintenance_category', 'The selected maintenance category is invalid.'); end if;
  if b ? 'cost' and (public.try_num(b ->> 'cost') is null or public.try_num(b ->> 'cost') < 0) then v_errs := public.err_add(v_errs, 'cost', 'The cost field must be at least 0.'); end if;
  if length(coalesce(b ->> 'description', '')) > 500 then v_errs := public.err_add(v_errs, 'description', 'The description field must not be greater than 500 characters.'); end if;
  perform public.throw_if_errors(v_errs);

  insert into public.vehicle_maintenance (vehicle_id, maintenance_type, maintenance_category, description, maintenance_date, completion_date, cost, next_due_date, status)
  values (public.try_int(b ->> 'vehicle_id'), b ->> 'type', coalesce(b ->> 'maintenance_category', 'preventive'), b ->> 'description', v_date,
          case when v_status = 'completed' then public.app_today() end, public.try_num(b ->> 'cost'), v_next, v_status)
  returning id into v_id;

  perform public.sync_vehicle_dates(v_id);
  if v_status = 'completed' then perform public.restore_vehicle_availability(v_id); end if;
  perform public.log_action(v_me.id, 'CREATE_MAINTENANCE', 'vehicle_maintenance', v_id::text);
  return jsonb_build_object('data', public.res_maintenance(v_id));
end $$;

create or replace function public.api_maintenance_update(p_id bigint, p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator'); b jsonb := public.strip_empty(p_body); m public.vehicle_maintenance; v_errs jsonb := '{}'::jsonb;
  v_veh bigint; v_type text; v_cat text; v_date date; v_next date; v_status text; v_completing boolean;
begin
  select * into m from public.vehicle_maintenance where id = p_id;
  if m.id is null then perform public.fail(404, 'No query results for model [App\Models\VehicleMaintenance] ' || p_id); end if;

  v_veh := coalesce(public.try_int(b ->> 'vehicle_id'), m.vehicle_id);
  v_type := coalesce(b ->> 'type', m.maintenance_type);
  v_cat := coalesce(b ->> 'maintenance_category', m.maintenance_category);
  v_date := case when b ? 'date_performed' then public.try_date(b ->> 'date_performed') else m.maintenance_date end;
  v_next := case when p_body ? 'next_due_date' then public.try_date(b ->> 'next_due_date') else m.next_due_date end;
  v_status := coalesce(b ->> 'status', m.status);

  if not exists (select 1 from public.vehicles where id = v_veh) then v_errs := public.err_add(v_errs, 'vehicle_id', 'The selected vehicle id is invalid.'); end if;
  if v_type not in ('oil_change', 'repair', 'refueling', 'inspection', 'tire_service', 'other') then v_errs := public.err_add(v_errs, 'type', 'The selected type is invalid.'); end if;
  if v_cat not in ('preventive', 'corrective') then v_errs := public.err_add(v_errs, 'maintenance_category', 'The selected maintenance category is invalid.'); end if;
  if v_date is null then v_errs := public.err_add(v_errs, 'date_performed', 'The date performed field must be a valid date.'); end if;
  if v_next is not null and v_date is not null and v_next < v_date then v_errs := public.err_add(v_errs, 'next_due_date', 'The next due date field must be a date after or equal to date performed.'); end if;
  if v_status not in ('scheduled', 'in_progress', 'completed', 'cancelled') then v_errs := public.err_add(v_errs, 'status', 'The selected status is invalid.'); end if;
  if b ? 'cost' and (public.try_num(b ->> 'cost') is null or public.try_num(b ->> 'cost') < 0) then v_errs := public.err_add(v_errs, 'cost', 'The cost field must be at least 0.'); end if;
  perform public.throw_if_errors(v_errs);

  v_completing := v_status = 'completed' and m.status <> 'completed';
  update public.vehicle_maintenance set
    vehicle_id = v_veh, maintenance_type = v_type, maintenance_category = v_cat, maintenance_date = v_date,
    next_due_date = v_next, status = v_status,
    description = case when p_body ? 'description' then nullif(p_body ->> 'description', '') else description end,
    cost = case when p_body ? 'cost' then public.try_num(b ->> 'cost') else cost end,
    completion_date = case when v_completing then public.app_today() else completion_date end
  where id = p_id;

  perform public.sync_vehicle_dates(p_id);
  if v_completing then perform public.restore_vehicle_availability(p_id); end if;
  perform public.log_action(v_me.id, case when p_body ->> 'status' = 'completed' then 'COMPLETE_MAINTENANCE' else 'UPDATE_MAINTENANCE' end, 'vehicle_maintenance', p_id::text);
  return jsonb_build_object('data', public.res_maintenance(p_id));
end $$;

-- ================= preventive maintenance checklist =================

create or replace function public.api_checklists_list(p_params jsonb default '{}') returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); v_ids bigint[];
begin
  select coalesce(array_agg(c.id order by c.inspection_date desc, c.id desc), '{}') into v_ids
  from public.preventive_maintenance_checklists c
  where nullif(p_params ->> 'vehicle_id', '') is null or c.vehicle_id = public.try_int(p_params ->> 'vehicle_id');
  return jsonb_build_object('data', public.collect('res_checklist', v_ids));
end $$;

create or replace function public.api_checklist_create(p_body jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me public.profiles := public.require_role('administrator'); b jsonb := public.strip_empty(p_body); v_errs jsonb := '{}'::jsonb; v_id bigint; f text;
begin
  if public.try_int(b ->> 'vehicle_id') is null or not exists (select 1 from public.vehicles where id = public.try_int(b ->> 'vehicle_id')) then v_errs := public.err_add(v_errs, 'vehicle_id', 'The selected vehicle id is invalid.'); end if;
  if public.try_date(b ->> 'inspection_date') is null then v_errs := public.err_add(v_errs, 'inspection_date', 'The inspection date field is required.'); end if;
  if b ? 'current_mileage' and (public.try_int(b ->> 'current_mileage') is null or public.try_int(b ->> 'current_mileage') < 0) then v_errs := public.err_add(v_errs, 'current_mileage', 'The current mileage field must be at least 0.'); end if;
  foreach f in array array['last_oil_change', 'last_air_filter_change', 'last_cabin_filter_change', 'last_oil_filter_change', 'last_engine_tune_up'] loop
    if b ? f and public.try_date(b ->> f) is null then v_errs := public.err_add(v_errs, f, 'The ' || replace(f, '_', ' ') || ' field must be a valid date.'); end if;
  end loop;
  foreach f in array array[
    'belts_condition', 'hoses_condition', 'engine_condition', 'air_conditioning_condition', 'wipers_condition', 'headlights_condition',
    'driving_lights_condition', 'brake_lights_condition', 'hazard_lights_condition', 'door_locks_condition', 'windows_windshield_condition',
    'radio_condition', 'tires_condition', 'liquid_levels_condition', 'other_parts_condition'
  ] loop
    if b ? f and (b ->> f) not in ('excellent', 'good', 'poor') then v_errs := public.err_add(v_errs, f, 'The selected ' || replace(f, '_', ' ') || ' is invalid.'); end if;
  end loop;
  perform public.throw_if_errors(v_errs);

  insert into public.preventive_maintenance_checklists (
    vehicle_id, pmuv_no, inspection_date, inspector_mechanic, current_mileage, last_oil_change, last_air_filter_change,
    last_cabin_filter_change, last_oil_filter_change, last_engine_tune_up,
    belts_condition, hoses_condition, engine_condition, air_conditioning_condition, wipers_condition, headlights_condition,
    driving_lights_condition, brake_lights_condition, hazard_lights_condition, door_locks_condition, windows_windshield_condition,
    radio_condition, tires_condition, liquid_levels_condition, other_parts_condition, other_parts, remarks, supervisor_recommendation
  )
  select r.vehicle_id, r.pmuv_no, r.inspection_date, r.inspector_mechanic, r.current_mileage, r.last_oil_change, r.last_air_filter_change,
    r.last_cabin_filter_change, r.last_oil_filter_change, r.last_engine_tune_up,
    r.belts_condition, r.hoses_condition, r.engine_condition, r.air_conditioning_condition, r.wipers_condition, r.headlights_condition,
    r.driving_lights_condition, r.brake_lights_condition, r.hazard_lights_condition, r.door_locks_condition, r.windows_windshield_condition,
    r.radio_condition, r.tires_condition, r.liquid_levels_condition, r.other_parts_condition, r.other_parts, r.remarks, r.supervisor_recommendation
  from jsonb_populate_record(null::public.preventive_maintenance_checklists, b) r
  returning id into v_id;

  perform public.log_action(v_me.id, 'CREATE_PREVENTIVE_MAINTENANCE_CHECKLIST', 'preventive_maintenance_checklists', v_id::text);
  return jsonb_build_object('data', public.res_checklist(v_id));
end $$;

create or replace function public.api_checklist_print_data(p_id bigint) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_me public.profiles := public.require_role('administrator'); c public.preventive_maintenance_checklists; v public.vehicles; j jsonb;
begin
  select * into c from public.preventive_maintenance_checklists where id = p_id;
  if c.id is null then perform public.fail(404, 'No query results for model [App\Models\PreventiveMaintenanceChecklist] ' || p_id); end if;
  select * into v from public.vehicles where id = c.vehicle_id;
  j := to_jsonb(c);
  return jsonb_build_object(
    'pmuvNo', coalesce(c.pmuv_no, ''), 'date', coalesce(to_char(c.inspection_date, 'Mon FMDD, YYYY'), ''),
    'vehicleModel', v.vehicle_model, 'plateNumber', v.plate_number, 'inspector', coalesce(c.inspector_mechanic, ''),
    'mileage', case when c.current_mileage is null then '' else to_char(c.current_mileage, 'FM999,999,999') || ' km' end,
    'serviceDates', jsonb_build_array(
      jsonb_build_object('label', 'Oil change', 'value', coalesce(to_char(c.last_oil_change, 'Mon FMDD, YYYY'), '')),
      jsonb_build_object('label', 'Air filter', 'value', coalesce(to_char(c.last_air_filter_change, 'Mon FMDD, YYYY'), '')),
      jsonb_build_object('label', 'Cabin filter', 'value', coalesce(to_char(c.last_cabin_filter_change, 'Mon FMDD, YYYY'), '')),
      jsonb_build_object('label', 'Oil filter', 'value', coalesce(to_char(c.last_oil_filter_change, 'Mon FMDD, YYYY'), '')),
      jsonb_build_object('label', 'Engine tune-up', 'value', coalesce(to_char(c.last_engine_tune_up, 'Mon FMDD, YYYY'), ''))
    ),
    'items', jsonb_build_array(
      jsonb_build_object('label', 'Belts', 'rating', j ->> 'belts_condition'),
      jsonb_build_object('label', 'Hoses', 'rating', j ->> 'hoses_condition'),
      jsonb_build_object('label', 'Engine', 'rating', j ->> 'engine_condition'),
      jsonb_build_object('label', 'Heat / Air conditioning', 'rating', j ->> 'air_conditioning_condition'),
      jsonb_build_object('label', 'Wipers', 'rating', j ->> 'wipers_condition'),
      jsonb_build_object('label', 'Headlights', 'rating', j ->> 'headlights_condition'),
      jsonb_build_object('label', 'Driving lights', 'rating', j ->> 'driving_lights_condition'),
      jsonb_build_object('label', 'Brake lights', 'rating', j ->> 'brake_lights_condition'),
      jsonb_build_object('label', 'Hazard lights', 'rating', j ->> 'hazard_lights_condition'),
      jsonb_build_object('label', 'Door locks', 'rating', j ->> 'door_locks_condition'),
      jsonb_build_object('label', 'Windows / Windshield', 'rating', j ->> 'windows_windshield_condition'),
      jsonb_build_object('label', 'Radio', 'rating', j ->> 'radio_condition'),
      jsonb_build_object('label', 'Tires', 'rating', j ->> 'tires_condition'),
      jsonb_build_object('label', 'Liquid levels', 'rating', j ->> 'liquid_levels_condition')
    ),
    'otherParts', coalesce(c.other_parts, ''), 'remarks', coalesce(c.remarks, ''), 'recommendation', coalesce(c.supervisor_recommendation, '')
  );
end $$;

-- ================= lock down =================
-- Only api_* functions are open to signed-in users (and api_login_precheck to the login page).
-- svc_* functions can only be called by the Edge Function (service role). Everything else is internal.

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname not like 'api\_%' and p.prokind = 'f'
      and p.prorettype <> 'pg_catalog.trigger'::regtype
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.sig);
    if r.proname like 'svc\_%' then
      execute format('grant execute on function %s to service_role', r.sig);
    end if;
  end loop;
end $$;

-- Optional: marks finished trips as completed every minute, like the Laravel scheduler did.
-- Turn on "pg_cron" under Database > Extensions first, then run:
-- select cron.schedule('complete-finished-trips', '* * * * *', 'select public.complete_finished_trips()');