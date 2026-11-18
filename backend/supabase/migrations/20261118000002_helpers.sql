set check_function_bodies = off;

-- ---------- time helpers (the app runs on Philippine time) ----------
create or replace function public.app_now() returns timestamp language sql stable as $$
  select now() at time zone 'Asia/Manila' $$;

create or replace function public.app_today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date $$;

create or replace function public.iso(ts timestamptz) returns text language sql immutable as $$
  select to_char(ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') $$;

create or replace function public.try_date(t text) returns date language plpgsql immutable as $$
begin return t::date; exception when others then return null; end $$;

create or replace function public.try_time(t text) returns time language plpgsql immutable as $$
begin return t::time; exception when others then return null; end $$;

create or replace function public.try_int(t text) returns int language plpgsql immutable as $$
begin return t::int; exception when others then return null; end $$;

create or replace function public.try_num(t text) returns numeric language plpgsql immutable as $$
begin return t::numeric; exception when others then return null; end $$;

create or replace function public.full_name(f text, l text) returns text language sql immutable as $$
  select btrim(coalesce(f, '') || ' ' || coalesce(l, '')) $$;

-- ---------- errors (the frontend adapter turns these into 422, 403, ... responses) ----------
create or replace function public.fail(p_status int, p_message text, p_errors jsonb default null, p_extra jsonb default '{}'::jsonb)
returns void language plpgsql as $$
declare v jsonb;
begin
  v := jsonb_build_object('status', p_status, 'message', p_message) || coalesce(p_extra, '{}'::jsonb);
  if p_errors is not null then
    v := v || jsonb_build_object('errors', p_errors);
  end if;
  raise exception '%', v::text using errcode = 'P0001';
end $$;

create or replace function public.fail_validation(p_field text, p_message text) returns void language plpgsql as $$
begin
  perform public.fail(422, p_message, jsonb_build_object(p_field, jsonb_build_array(p_message)));
end $$;

create or replace function public.err_add(p jsonb, f text, m text) returns jsonb language sql immutable as $$
  select p || jsonb_build_object(f, coalesce(p -> f, '[]'::jsonb) || to_jsonb(m)) $$;

create or replace function public.throw_if_errors(p jsonb) returns void language plpgsql as $$
begin
  if p <> '{}'::jsonb then
    perform public.fail(422, (select e.value ->> 0 from jsonb_each(p) e limit 1), p);
  end if;
end $$;

-- Empty strings count as "not sent", like Laravel does
create or replace function public.strip_empty(b jsonb) returns jsonb language sql immutable as $$
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) from jsonb_each(b) e where e.value <> '""'::jsonb $$;

-- ---------- who is calling ----------
create or replace function public.me() returns public.profiles language sql stable security definer set search_path = public as $$
  select * from public.profiles where auth_id = auth.uid() limit 1 $$;

create or replace function public.require_auth() returns public.profiles language plpgsql security definer set search_path = public as $$
declare v public.profiles;
begin
  if auth.uid() is null then
    perform public.fail(401, 'Unauthenticated.');
  end if;
  v := public.me();
  if v.id is null or not v.is_active then
    perform public.fail(403, 'This account is not active.');
  end if;
  return v;
end $$;

create or replace function public.require_role(variadic p_roles text[]) returns public.profiles language plpgsql security definer set search_path = public as $$
declare v public.profiles;
begin
  v := public.require_auth();
  if not (v.role = any (p_roles)) then
    perform public.fail(403, 'You are not authorized to perform this action.');
  end if;
  return v;
end $$;

-- ---------- audit log ----------
create or replace function public.log_action(p_user bigint, p_action text, p_table text, p_target text, p_ip text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_ip text := p_ip;
begin
  if v_ip is null then
    begin
      v_ip := nullif(trim(split_part(coalesce(current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for', ''), ',', 1)), '');
    exception when others then
      v_ip := null;
    end;
  end if;
  insert into public.audit_logs (user_id, action, target_table, target_id, ip_address)
  values (p_user, p_action, p_table, p_target, v_ip);
end $$;

-- ---------- paging ----------
create or replace function public.collect(p_fn text, p_ids bigint[]) returns jsonb language plpgsql stable as $$
declare v jsonb;
begin
  execute format(
    'select coalesce(jsonb_agg(public.%I(x.i) order by x.o), ''[]''::jsonb) from unnest($1) with ordinality as x(i, o)', p_fn
  ) into v using p_ids;
  return v;
end $$;

create or replace function public.page_result(p_data jsonb, p_page int, p_per int, p_total int) returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'data', p_data,
    'meta', jsonb_build_object(
      'current_page', p_page,
      'last_page', greatest(ceil(p_total::numeric / p_per)::int, 1),
      'per_page', p_per,
      'total', p_total
    )
  ) $$;

-- ---------- resources (same shapes as the Laravel resources) ----------
create or replace function public.res_user(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', p.id, 'first_name', p.first_name, 'last_name', p.last_name, 'email', p.email, 'role', p.role,
    'position', p."position", 'phone_number', p.phone_number, 'is_active', p.is_active,
    'deletion_requested_at', public.iso(p.deletion_requested_at),
    'deletion_due_at', public.iso(p.deletion_requested_at + interval '30 days')
  ) from public.profiles p where p.id = p_id $$;

create or replace function public.res_vehicle(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', v.id, 'plate_number', v.plate_number, 'vehicle_model', v.vehicle_model, 'vehicle_type', v.vehicle_type,
    'color', v.color, 'manufacture_year', v.manufacture_year, 'capacity', v.capacity, 'mileage', v.mileage,
    'status', v.status, 'last_maintenance_date', v.last_maintenance_date::text,
    'next_maintenance_date', v.next_maintenance_date::text, 'is_active', v.is_active
  ) from public.vehicles v where v.id = p_id $$;

create or replace function public.vehicle_option(p_id bigint, p_reason text default null) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', v.id,
    'label', v.plate_number || ' — ' || v.vehicle_model || case when coalesce(v.capacity, 0) > 0 then ' (' || v.capacity || ' seats)' else '' end,
    'vehicle_model', v.vehicle_model, 'plate_number', v.plate_number, 'capacity', v.capacity,
    'available', p_reason is null, 'unavailable_reason', p_reason
  ) from public.vehicles v where v.id = p_id $$;

create or replace function public.driver_option(p_id bigint, p_reason text default null) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', d.id,
    'label', n.name
      || case when nullif(d.contact_number, '') is not null then ' · ' || d.contact_number else '' end
      || case when d.license_expiry_date is not null then ' (Lic. exp. ' || to_char(d.license_expiry_date, 'Mon YYYY') || ')' else '' end,
    'name', n.name, 'contact_number', d.contact_number, 'license_expiry_date', d.license_expiry_date::text,
    'available', p_reason is null, 'unavailable_reason', p_reason
  ) from public.drivers d
  cross join lateral (select coalesce(nullif(public.full_name(d.first_name, d.last_name), ''), 'Driver #' || d.id) as name) n
  where d.id = p_id $$;

create or replace function public.res_vehicle_request(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', r.id, 'status', r.status, 'booking_source', coalesce(r.booking_source, 'online'),
    'requester_name', coalesce(nullif(r.requester_name, ''), public.full_name(q.first_name, q.last_name)),
    'requester_department', r.requester_department, 'requester_contact', r.requester_contact,
    'destination', r.destination, 'purpose', r.purpose,
    'trip_date', r.trip_date::text, 'trip_end_date', r.trip_end_date::text,
    'travel_days', (r.trip_end_date - r.trip_date) + 1,
    'trip_type', r.trip_type, 'departure_time', r.departure_time::text, 'return_time', r.estimated_return_time::text,
    'passengers', r.passengers, 'number_of_passengers', r.number_of_passengers,
    'disapproval_reason', r.disapproval_reason, 'edit_reason', r.edit_reason,
    'approved_by', r.approved_by, 'approved_date', public.iso(r.approved_date),
    'requested_by', case when q.id is null then null else jsonb_build_object('id', q.id, 'first_name', q.first_name, 'last_name', q.last_name) end,
    'created_at', public.iso(r.created_at)
  ) from public.vehicle_requests r left join public.profiles q on q.id = r.requester_id where r.id = p_id $$;

create or replace function public.res_trip(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', t.id, 'vehicle_request_id', t.vehicle_request_id, 'vehicle_id', t.vehicle_id, 'driver_id', t.driver_id,
    'trip_date', t.trip_date::text, 'departure_time', t.departure_time::text,
    'estimated_return_time', t.estimated_return_time::text, 'destination', t.destination, 'purpose', t.purpose,
    'trip_status', t.trip_status, 'actual_departure_time', t.actual_departure_time::text,
    'actual_return_time', t.actual_return_time::text, 'actual_mileage', t.actual_mileage, 'notes', t.notes,
    'cancellation_reason', t.cancellation_reason,
    'cancelled_by', public.full_name(cb.first_name, cb.last_name),
    'cancelled_at', public.iso(t.cancelled_at),
    'vehicle_request', case when r.id is null then null else jsonb_build_object(
      'id', r.id, 'status', r.status, 'trip_type', r.trip_type, 'trip_date', r.trip_date::text,
      'trip_end_date', r.trip_end_date::text, 'number_of_passengers', r.number_of_passengers,
      'booking_source', coalesce(r.booking_source, 'online'),
      'requester_name', coalesce(nullif(r.requester_name, ''), public.full_name(q.first_name, q.last_name)),
      'requester_department', r.requester_department, 'requester_contact', r.requester_contact,
      'requester', case when q.id is null then null else jsonb_build_object('id', q.id, 'first_name', q.first_name, 'last_name', q.last_name) end
    ) end,
    'vehicle', case when v.id is null then null else jsonb_build_object('id', v.id, 'plate_number', v.plate_number, 'vehicle_model', v.vehicle_model) end,
    'driver', case when d.id is null then null else jsonb_build_object(
      'id', d.id, 'first_name', d.first_name, 'last_name', d.last_name,
      'name', public.full_name(d.first_name, d.last_name), 'contact_number', d.contact_number) end
  ) from public.trips t
  left join public.vehicle_requests r on r.id = t.vehicle_request_id
  left join public.profiles q on q.id = r.requester_id
  left join public.profiles cb on cb.id = t.cancelled_by
  left join public.vehicles v on v.id = t.vehicle_id
  left join public.drivers d on d.id = t.driver_id
  where t.id = p_id $$;

create or replace function public.res_allocation(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', a.id, 'status', t.trip_status,
    'trip', jsonb_build_object(
      'id', t.id, 'trip_date', t.trip_date::text, 'trip_end_date', coalesce(r.trip_end_date, t.trip_date)::text,
      'departure_time', t.departure_time::text, 'estimated_return_time', t.estimated_return_time::text,
      'destination', t.destination, 'purpose', t.purpose, 'cancellation_reason', t.cancellation_reason,
      'cancelled_by', public.full_name(cb.first_name, cb.last_name), 'cancelled_at', public.iso(t.cancelled_at)
    ),
    'vehicle_request', jsonb_build_object(
      'id', r.id, 'status', r.status, 'trip_type', r.trip_type, 'booking_source', coalesce(r.booking_source, 'online'),
      'requester', coalesce(nullif(public.full_name(q.first_name, q.last_name), ''), r.requester_name),
      'requester_department', r.requester_department, 'requester_contact', r.requester_contact,
      'number_of_passengers', r.number_of_passengers
    ),
    'vehicle', jsonb_build_object('id', v.id, 'plate_number', v.plate_number, 'vehicle_model', v.vehicle_model, 'capacity', v.capacity),
    'driver', jsonb_build_object(
      'id', d.id, 'name', public.full_name(d.first_name, d.last_name),
      'contact_number', d.contact_number, 'license_number', d.license_number
    ),
    'allocated_by', public.full_name(ab.first_name, ab.last_name),
    'allocation_date', public.iso(a.allocation_date), 'notes', a.notes,
    'created_at', public.iso(a.created_at), 'updated_at', public.iso(a.updated_at)
  ) from public.allocations a
  left join public.trips t on t.id = a.trip_id
  left join public.vehicle_requests r on r.id = t.vehicle_request_id
  left join public.profiles q on q.id = r.requester_id
  left join public.profiles cb on cb.id = t.cancelled_by
  left join public.profiles ab on ab.id = a.allocated_by
  left join public.vehicles v on v.id = a.vehicle_id
  left join public.drivers d on d.id = a.driver_id
  where a.id = p_id $$;

create or replace function public.res_reschedule(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', x.id, 'status', x.status, 'old_date', x.old_date::text, 'new_date', x.new_date::text,
    'reason', x.reason, 'admin_reason', x.admin_reason,
    'requested_by', public.full_name(rq.first_name, rq.last_name),
    'handled_by', public.full_name(h.first_name, h.last_name),
    'handled_at', public.iso(x.handled_at), 'created_at', public.iso(x.created_at),
    'allocation_id', (select a.id from public.allocations a where a.trip_id = x.trip_id),
    'trip', jsonb_build_object(
      'id', t.id, 'destination', t.destination, 'trip_date', t.trip_date::text,
      'departure_time', t.departure_time::text, 'estimated_return_time', t.estimated_return_time::text
    )
  ) from public.reschedule_requests x
  left join public.trips t on t.id = x.trip_id
  left join public.profiles rq on rq.id = x.requested_by
  left join public.profiles h on h.id = x.handled_by
  where x.id = p_id $$;

create or replace function public.res_share(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', s.id, 'created_at', public.iso(s.created_at),
    'sender', jsonb_build_object('id', a.id, 'name', public.full_name(a.first_name, a.last_name), 'email', a.email),
    'recipient', jsonb_build_object('id', b.id, 'name', public.full_name(b.first_name, b.last_name), 'email', b.email),
    'allocation', public.res_allocation(s.allocation_id)
  ) from public.trip_request_shares s
  join public.profiles a on a.id = s.sender_id
  join public.profiles b on b.id = s.recipient_id
  where s.id = p_id $$;

create or replace function public.res_maintenance(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', m.id,
    'vehicle', jsonb_build_object('id', v.id, 'plate_number', v.plate_number, 'model', v.vehicle_model, 'mileage', v.mileage),
    'type', m.maintenance_type, 'maintenance_category', m.maintenance_category, 'description', m.description,
    'status', m.status, 'date_performed', m.maintenance_date::text, 'completion_date', m.completion_date::text,
    'cost', m.cost, 'next_due_date', m.next_due_date::text, 'created_at', public.iso(m.created_at)
  ) from public.vehicle_maintenance m join public.vehicles v on v.id = m.vehicle_id where m.id = p_id $$;

create or replace function public.res_checklist(p_id bigint) returns jsonb language sql stable as $$
  select (to_jsonb(c) - 'vehicle_id' - 'updated_at')
    || jsonb_build_object('vehicle', jsonb_build_object('id', v.id, 'plate_number', v.plate_number, 'vehicle_model', v.vehicle_model))
  from public.preventive_maintenance_checklists c join public.vehicles v on v.id = c.vehicle_id where c.id = p_id $$;

create or replace function public.res_audit(p_id bigint) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', l.id, 'created_at', public.iso(l.created_at),
    'user', case when u.id is null then null else jsonb_build_object('id', u.id, 'name', public.full_name(u.first_name, u.last_name), 'email', u.email) end,
    'action', l.action, 'target_table', l.target_table, 'target_id', l.target_id, 'ip_address', l.ip_address
  ) from public.audit_logs l left join public.profiles u on u.id = l.user_id where l.id = p_id $$;