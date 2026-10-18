-- Staff role, account management (edit, 30-day deletion) and extra read views.
-- Matches UserController, EnsureUserHasRole and the staff routes of the Laravel version.

-- ---------------------------------------------------------------- staff role
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
    add constraint profiles_role_check check (role in ('administrator', 'faculty', 'staff'));

-- Same as users.deletion_requested_at in Laravel.
alter table public.profiles add column if not exists deletion_requested_at timestamptz;

create function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'staff' and is_active
    )
$$;

create function public.is_admin_or_staff() returns boolean
language sql stable security definer set search_path = public as $$
    select exists (
        select 1 from public.profiles
        where id = auth.uid() and role in ('administrator', 'staff') and is_active
    )
$$;

create function private.require_admin_or_staff() returns void
language plpgsql as $$
begin
    if not public.is_admin_or_staff() then
        perform private.http_error(403, 'You are not authorized to perform this action.');
    end if;
end $$;

-- ---------------------------------------------------------------- RLS: let staff read what Laravel lets them read
-- Staff also need to read faculty names (the requester shown on requests and trips).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
    using (id = auth.uid() or public.is_admin_or_staff() or role = 'administrator');

-- Profiles can no longer be changed directly (this allowed role changes).
-- Changes now go through update_user, request_user_deletion and cancel_user_deletion.
drop policy if exists profiles_update on public.profiles;

drop policy if exists requests_select on public.vehicle_requests;
create policy requests_select on public.vehicle_requests for select to authenticated
    using (public.is_admin_or_staff() or requester_id = auth.uid());

drop policy if exists vehicles_select on public.vehicles;
create policy vehicles_select on public.vehicles for select to authenticated
    using (
        public.is_admin_or_staff()
        or exists (
            select 1 from public.trips t
            join public.vehicle_requests r on r.id = t.vehicle_request_id
            where t.vehicle_id = vehicles.id and r.requester_id = auth.uid()
        )
    );

drop policy if exists drivers_select on public.drivers;
create policy drivers_select on public.drivers for select to authenticated
    using (
        public.is_admin_or_staff()
        or exists (
            select 1 from public.trips t
            join public.vehicle_requests r on r.id = t.vehicle_request_id
            where t.driver_id = drivers.id and r.requester_id = auth.uid()
        )
    );

drop policy if exists trips_select on public.trips;
create policy trips_select on public.trips for select to authenticated
    using (
        public.is_admin_or_staff()
        or exists (select 1 from public.vehicle_requests r
                   where r.id = trips.vehicle_request_id and r.requester_id = auth.uid())
    );

drop policy if exists allocations_select on public.allocations;
create policy allocations_select on public.allocations for select to authenticated
    using (
        public.is_admin_or_staff()
        or exists (select 1 from public.trips t
                   join public.vehicle_requests r on r.id = t.vehicle_request_id
                   where t.id = allocations.trip_id and r.requester_id = auth.uid())
    );

drop policy if exists reschedule_select on public.reschedule_requests;
create policy reschedule_select on public.reschedule_requests for select to authenticated
    using (
        public.is_admin_or_staff()
        or exists (select 1 from public.trips t
                   join public.vehicle_requests r on r.id = t.vehicle_request_id
                   where t.id = reschedule_requests.trip_id and r.requester_id = auth.uid())
    );

drop policy if exists shares_select on public.trip_request_shares;
create policy shares_select on public.trip_request_shares for select to authenticated
    using (public.is_admin_or_staff() and recipient_id = auth.uid());

drop policy if exists shares_insert on public.trip_request_shares;
create policy shares_insert on public.trip_request_shares for insert to authenticated
    with check (
        public.is_admin_or_staff()
        and sender_id = auth.uid()
        and recipient_id <> auth.uid()
        and exists (select 1 from public.profiles p
                    where p.id = recipient_id and p.role = 'administrator' and p.is_active)
    );

-- ---------------------------------------------------------------- user shape (same as UserResource)
create function private.user_json(p public.profiles) returns jsonb
language sql stable as $$
    select jsonb_build_object(
        'id', p.id,
        'first_name', p.first_name,
        'last_name', p.last_name,
        'email', p.email,
        'role', p.role,
        'position', p.position,
        'phone_number', p.phone_number,
        'is_active', p.is_active,
        'deletion_requested_at', p.deletion_requested_at,
        'deletion_due_at', p.deletion_requested_at + interval '30 days'
    )
$$;

-- ---------------------------------------------------------------- GET /users
-- Administrators only. Order in the client: sort_group, last_name, first_name
-- (accounts pending deletion go last, as in UserController::index).
create view public.users_ordered with (security_invoker = true) as
select p.*,
       case when p.deletion_requested_at is not null then 1 else 0 end as sort_group,
       p.deletion_requested_at + interval '30 days' as deletion_due_at
from public.profiles p
where public.is_admin();

-- ---------------------------------------------------------------- GET /vehicle-requests/approved
-- Approved requests that do not have a trip yet. Administrators only.
-- Order in the client: trip_date, departure_time.
create view public.approved_vehicle_requests with (security_invoker = true) as
select r.*,
       (select pr.full_name from public.profiles pr where pr.id = r.requester_id) as requester_name
from public.vehicle_requests r
where r.status = 'approved'
  and public.is_admin()
  and not exists (select 1 from public.trips t where t.vehicle_request_id = r.id);

-- ---------------------------------------------------------------- PUT /users/{user}
-- Pass the current value for any field that should stay the same.
-- Leave p_password empty to keep the current password.
create function public.update_user(
    p_user_id uuid,
    p_first_name text,
    p_last_name text,
    p_email text,
    p_role text,
    p_position text default null,
    p_phone_number text default null,
    p_password text default null
) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    u public.profiles%rowtype;
    v_new_password boolean := coalesce(p_password, '') <> '';
begin
    perform private.require_admin();

    select * into u from public.profiles where id = p_user_id for update;
    if not found then perform private.http_error(404, 'User not found.'); end if;

    if coalesce(trim(p_first_name), '') = '' or char_length(p_first_name) > 100 then
        perform private.fail('The first name field is required (max 100).', 'first_name');
    end if;
    if coalesce(trim(p_last_name), '') = '' or char_length(p_last_name) > 100 then
        perform private.fail('The last name field is required (max 100).', 'last_name');
    end if;
    if coalesce(p_email, '') !~ '^\S+@\S+\.\S+$' or char_length(p_email) > 255 then
        perform private.fail('The email must be a valid email address.', 'email');
    end if;
    if exists (select 1 from public.profiles where lower(email) = lower(trim(p_email)) and id <> u.id) then
        perform private.fail('The email has already been taken.', 'email');
    end if;
    if p_role is null or p_role not in ('administrator', 'faculty', 'staff') then
        perform private.fail('The selected role is invalid.', 'role');
    end if;
    if p_position is not null and char_length(p_position) > 255 then
        perform private.fail('The position may not be greater than 255 characters.', 'position');
    end if;
    if p_phone_number is not null and char_length(p_phone_number) > 20 then
        perform private.fail('The phone number may not be greater than 20 characters.', 'phone_number');
    end if;
    if v_new_password and char_length(p_password) < 8 then
        perform private.fail('The password must be at least 8 characters.', 'password');
    end if;

    -- Admin accounts may be edited, but never converted to another role.
    if u.role = 'administrator' and p_role <> 'administrator' then
        perform private.fail('Administrator accounts must keep the Administrator role.');
    end if;

    update public.profiles
    set first_name = trim(p_first_name),
        last_name = trim(p_last_name),
        email = trim(p_email),
        position = p_position,
        phone_number = p_phone_number,
        role = p_role
    where id = u.id
    returning * into u;

    -- Keep the login account in step with the profile.
    update auth.users
    set email = trim(p_email),
        raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', p_role),
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
            'first_name', trim(p_first_name),
            'last_name', trim(p_last_name),
            'position', p_position,
            'phone_number', p_phone_number
        ),
        encrypted_password = case when v_new_password
                                  then extensions.crypt(p_password, extensions.gen_salt('bf'))
                                  else encrypted_password end,
        updated_at = now()
    where id = u.id;

    update auth.identities
    set identity_data = identity_data || jsonb_build_object('email', trim(p_email)),
        updated_at = now()
    where user_id = u.id and provider = 'email';

    return private.user_json(u);
end $$;

-- ---------------------------------------------------------------- DELETE /users/{user}
-- The account is disabled right away and removed after 30 days (see process_account_deletions).
create function public.request_user_deletion(p_user_id uuid) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    u public.profiles%rowtype;
begin
    perform private.require_admin();

    select * into u from public.profiles where id = p_user_id for update;
    if not found then perform private.http_error(404, 'User not found.'); end if;

    if u.role = 'administrator' then
        perform private.fail('Administrator accounts cannot be deleted.');
    end if;
    if u.deletion_requested_at is not null then
        perform private.fail('This account is already pending deletion.');
    end if;
    if u.id = auth.uid() then
        perform private.fail('You cannot schedule your own account for deletion.');
    end if;

    update public.profiles
    set deletion_requested_at = now(), is_active = false
    where id = u.id
    returning * into u;

    -- Block sign-in and end every open session (same as deleting the tokens in Laravel).
    update auth.users set banned_until = now() + interval '100 years' where id = u.id;
    delete from auth.sessions where user_id = u.id;

    return jsonb_build_object(
        'message', 'Account scheduled for deletion in 30 days. It is disabled immediately and can be restored during the waiting period.',
        'user', private.user_json(u)
    );
end $$;

-- ---------------------------------------------------------------- POST /users/{user}/cancel-deletion
create function public.cancel_user_deletion(p_user_id uuid) returns jsonb
language plpgsql security definer set search_path = public, private as $$
declare
    u public.profiles%rowtype;
begin
    perform private.require_admin();

    select * into u from public.profiles where id = p_user_id for update;
    if not found then perform private.http_error(404, 'User not found.'); end if;

    if u.deletion_requested_at is null then
        perform private.fail('This account is not pending deletion.');
    end if;
    if u.deletion_requested_at + interval '30 days' <= now() then
        perform private.fail('The 30-day deletion period has expired.');
    end if;

    update public.profiles
    set deletion_requested_at = null, is_active = true
    where id = u.id
    returning * into u;

    update auth.users set banned_until = null where id = u.id;

    return private.user_json(u);
end $$;

-- ---------------------------------------------------------------- users:process-deletions
-- Anonymizes accounts whose 30-day period has ended. The profile row is kept so old requests,
-- allocations and trips still point to it. Administrator accounts are skipped.
create function private.process_account_deletions() returns integer
language plpgsql security definer set search_path = public, private as $$
declare
    u record;
    v_count integer := 0;
begin
    for u in
        select id from public.profiles
        where deletion_requested_at is not null
          and deletion_requested_at <= now() - interval '30 days'
          and role <> 'administrator'
    loop
        delete from auth.sessions where user_id = u.id;
        delete from auth.identities where user_id = u.id;

        update auth.users
        set email = 'deleted-user-' || u.id || '@deleted.invalid',
            encrypted_password = extensions.crypt(gen_random_uuid()::text || gen_random_uuid()::text,
                                                  extensions.gen_salt('bf')),
            raw_user_meta_data = '{}'::jsonb,
            banned_until = now() + interval '100 years',
            updated_at = now()
        where id = u.id;

        update public.profiles
        set email = 'deleted-user-' || u.id || '@deleted.invalid',
            first_name = 'Deleted',
            last_name = 'User',
            position = null,
            phone_number = null,
            is_active = false,
            deletion_requested_at = null
        where id = u.id;

        v_count := v_count + 1;
    end loop;

    return v_count;
end $$;

-- Runs every day at 00:00 Philippine time (16:00 UTC), like the Laravel daily schedule.
create extension if not exists pg_cron;
select cron.schedule('process-account-deletions', '0 16 * * *', $$select private.process_account_deletions()$$);

-- ---------------------------------------------------------------- permissions
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;

revoke all on public.users_ordered, public.approved_vehicle_requests from anon;
grant select on public.users_ordered, public.approved_vehicle_requests to authenticated;