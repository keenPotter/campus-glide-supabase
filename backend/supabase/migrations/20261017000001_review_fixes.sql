-- Fixes found during code review. Written as a new migration so it also works
-- if the earlier migrations were already applied.

-- 1. Take the role from app_metadata (writable only by the service role), not from
--    user_metadata (which anyone can set through the public sign-up endpoint).
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
    insert into public.profiles (id, email, first_name, last_name, position, phone_number, role)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data ->> 'first_name', ''),
        coalesce(new.raw_user_meta_data ->> 'last_name', ''),
        new.raw_user_meta_data ->> 'position',
        new.raw_user_meta_data ->> 'phone_number',
        coalesce(new.raw_app_meta_data ->> 'role', 'faculty')
    );
    return new;
end $$;

-- 2. The "today or later" rule only ran on insert. Also apply it when the trip date changes
--    (faculty editing a request, or a date change being approved).
create trigger trg_vehicle_requests_validate_date
    before update of trip_date on public.vehicle_requests
    for each row
    when (new.trip_date is distinct from old.trip_date)
    execute function private.validate_vehicle_request();