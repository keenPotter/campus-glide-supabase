// Creates and updates accounts. These actions need Supabase's admin key, so they cannot run in the browser.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (status, body) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

const ROLES = ['administrator', 'faculty', 'staff']
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

function required(data, fields, errors) {
  for (const field of fields) {
    if (!String(data[field] ?? '').trim()) {
      errors[field] = [`The ${field.replaceAll('_', ' ')} field is required.`]
    }
  }
}

async function emailTaken(admin, email, exceptId = null) {
  let query = admin.from('profiles').select('id').ilike('email', email)
  if (exceptId) query = query.neq('id', exceptId)
  const { data } = await query.limit(1)
  return Boolean(data?.length)
}

async function validateNewUser(admin, data, needsRole) {
  const errors = {}
  required(data, ['first_name', 'last_name', 'email', 'password'], errors)
  if (needsRole) required(data, ['role'], errors)

  if (data.email && !errors.email) {
    if (!EMAIL.test(data.email)) errors.email = ['The email field must be a valid email address.']
    else if (await emailTaken(admin, data.email)) errors.email = ['The email has already been taken.']
  }
  if (needsRole && data.role && !ROLES.includes(data.role)) errors.role = ['The selected role is invalid.']
  if (data.password && !errors.password) {
    if (String(data.password).length < 8) errors.password = ['The password field must be at least 8 characters.']
    else if (data.password !== data.password_confirmation) errors.password = ['The password field confirmation does not match.']
  }
  return errors
}

// Reads the JSON error that our SQL functions raise
function rpcFailure(error) {
  try {
    const body = JSON.parse(error.message)
    return json(body.status ?? 400, body)
  } catch {
    return json(500, { message: error.message || 'Something went wrong.' })
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const url = Deno.env.get('SUPABASE_URL')
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY'), {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    })
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Only an active administrator may continue
    const { data: me, error: meError } = await caller.rpc('api_me')
    if (meError || !me?.data) return json(401, { message: 'Unauthenticated.' })
    const actor = me.data
    if (actor.role !== 'administrator' || !actor.is_active) {
      return json(403, { message: 'You are not authorized to perform this action.' })
    }

    const { action, id, data = {} } = await req.json()
    const ip = (req.headers.get('x-forwarded-for') ?? '').split(',')[0].trim() || null
    if (data.email) data.email = String(data.email).trim().toLowerCase()

    // ---------- create account ----------
    if (action === 'register' || action === 'transfer') {
      const errors = await validateNewUser(admin, data, action === 'register')
      if (Object.keys(errors).length) {
        return json(422, { message: Object.values(errors)[0][0], errors })
      }

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email: data.email,
        password: data.password,
        email_confirm: true,
      })
      if (createError) {
        return json(422, { message: createError.message, errors: { email: [createError.message] } })
      }

      const rpcName = action === 'register' ? 'svc_create_profile' : 'svc_admin_transfer'
      const { data: result, error: rpcError } = await admin.rpc(rpcName, {
        p_auth_id: created.user.id,
        p_data: data,
        p_actor: actor.id,
        p_ip: ip,
      })
      if (rpcError) {
        await admin.auth.admin.deleteUser(created.user.id) // undo, so no account is left half-made
        return rpcFailure(rpcError)
      }
      return json(201, result)
    }

    // ---------- edit account ----------
    if (action === 'update') {
      const { data: before } = await admin.from('profiles').select('auth_id, email').eq('id', id).maybeSingle()
      if (!before) return json(404, { message: 'No query results for model [App\\Models\\User] ' + id })

      if (data.password && String(data.password).length < 8) {
        return json(422, {
          message: 'The password field must be at least 8 characters.',
          errors: { password: ['The password field must be at least 8 characters.'] },
        })
      }

      const { data: result, error: rpcError } = await admin.rpc('svc_update_profile', {
        p_id: id,
        p_data: data,
        p_actor: actor.id,
        p_ip: ip,
      })
      if (rpcError) return rpcFailure(rpcError)

      const changes = {}
      if (data.email && data.email !== before.email) changes.email = data.email
      if (data.password) changes.password = data.password
      if (before.auth_id && Object.keys(changes).length) {
        const { error: authError } = await admin.auth.admin.updateUserById(before.auth_id, changes)
        if (authError) {
          return json(422, { message: authError.message, errors: { email: [authError.message] } })
        }
      }
      return json(200, result)
    }

    return json(400, { message: 'Unknown action.' })
  } catch (error) {
    return json(500, { message: error?.message ?? 'Something went wrong.' })
  }
})