// POST /functions/v1/register-user  (replaces AuthController::register)
// Creates a user account. Administrators only.
// The profile row is created by the on_auth_user_created trigger.
import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

const invalid = (field: string, message: string) => json({ message, errors: { [field]: [message] } }, 422)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ message: 'Method not allowed.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')!
  const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  // Only an active administrator may create accounts.
  const { data: { user } } = await caller.auth.getUser()
  if (!user) return json({ message: 'Unauthenticated.' }, 401)

  const { data: me } = await admin.from('profiles').select('role, is_active').eq('id', user.id).single()
  if (!me || me.role !== 'administrator' || !me.is_active) {
    return json({ message: 'You are not authorized to perform this action.' }, 403)
  }

  const b = await req.json().catch(() => ({}))

  if (!b.first_name?.trim() || b.first_name.length > 100) return invalid('first_name', 'The first name field is required (max 100).')
  if (!b.last_name?.trim() || b.last_name.length > 100) return invalid('last_name', 'The last name field is required (max 100).')
  if (!/^\S+@\S+\.\S+$/.test(b.email ?? '') || b.email.length > 255) return invalid('email', 'The email must be a valid email address.')
  if (typeof b.password !== 'string' || b.password.length < 8) return invalid('password', 'The password must be at least 8 characters.')
  if (b.password !== b.password_confirmation) return invalid('password', 'The password confirmation does not match.')
  if (!['administrator', 'faculty', 'staff'].includes(b.role)) return invalid('role', 'The selected role is invalid.')
  if (b.position && b.position.length > 255) return invalid('position', 'The position may not be greater than 255 characters.')
  if (b.phone_number && b.phone_number.length > 20) return invalid('phone_number', 'The phone number may not be greater than 20 characters.')

  const { data, error } = await admin.auth.admin.createUser({
    email: b.email,
    password: b.password,
    email_confirm: true,
    // The role must be in app_metadata. The sign-up trigger reads it from there.
    app_metadata: { role: b.role },
    user_metadata: {
      first_name: b.first_name.trim(),
      last_name: b.last_name.trim(),
      position: b.position ?? null,
      phone_number: b.phone_number ?? null,
    },
  })

  if (error) {
    const taken = /already|registered|exists/i.test(error.message)
    return invalid('email', taken ? 'The email has already been taken.' : error.message)
  }

  const { data: profile } = await admin
    .from('profiles')
    .select('id, first_name, last_name, email, role, position, phone_number, is_active, deletion_requested_at')
    .eq('id', data.user.id)
    .single()

  return json({ data: { ...profile, deletion_due_at: null }, message: 'User registered successfully' }, 201)
})