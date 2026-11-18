import { supabase } from '@/lib/supabase'
import { buildAllocationFormHtml, buildChecklistHtml } from '@/lib/printForms'

/**
 * Keeps the old api.get / api.post / api.put / api.patch / api.delete calls working,
 * but sends them to Supabase instead of the Laravel server.
 * Every route below points to one SQL function (api_*) or to the admin-users Edge Function.
 * Responses and errors have the same shape as before, so the pages do not change.
 */

function clean(object = {}) {
  return Object.fromEntries(
    Object.entries(object).filter(([, value]) => value !== undefined && value !== null && value !== ''),
  )
}

function fail(status, body) {
  const error = new Error(body?.message ?? 'Request failed')
  error.response = { status, data: body }
  return error
}

function fromRpcError(error) {
  try {
    const body = JSON.parse(error.message)
    if (body?.status) return fail(body.status, body)
  } catch {
    // not one of our own errors
  }

  const expired = error.code === 'PGRST301' || /jwt/i.test(error.message ?? '')
  return fail(expired ? 401 : 500, {
    message: expired ? 'Unauthenticated.' : error.message || 'Something went wrong. Please try again.',
  })
}

async function rpc(name, args = {}) {
  const { data, error } = await supabase.rpc(name, args)
  if (error) throw fromRpcError(error)
  return data
}

async function invokeUsers(payload) {
  const { data, error } = await supabase.functions.invoke('admin-users', { body: payload })
  if (error) {
    let status = 500
    let body = { message: error.message }
    try {
      status = error.context.status
      body = await error.context.json()
    } catch {
      // keep the default message
    }
    throw fail(status, body)
  }
  return data
}

async function onUnauthenticated() {
  await supabase.auth.signOut({ scope: 'local' })
  if (!window.location.pathname.startsWith('/login')) {
    window.location.assign('/login')
  }
}

const num = (value) => Number(value)

/* ================= routes ================= */

const routes = [
  // ----- session -----
  [
    'POST',
    /^\/login$/,
    async ({ body }) => {
      const email = String(body.email ?? '').trim().toLowerCase()
      const wrong = (field, message) => fail(422, { message, errors: { [field]: [message] } })

      const check = await rpc('api_login_precheck', { p_email: email })
      if (!check?.found) throw wrong('email', 'The provided email address is incorrect.')

      const { data, error } = await supabase.auth.signInWithPassword({ email, password: body.password })
      if (error) throw wrong('password', 'The provided password is incorrect.')

      const me = (await rpc('api_me')).data
      if (!me.is_active) {
        await supabase.auth.signOut({ scope: 'local' })
        throw wrong('email', 'This account has been deactivated.')
      }
      if (me.role !== body.role) {
        await supabase.auth.signOut({ scope: 'local' })
        throw wrong('role', 'The selected account type does not match this account.')
      }

      await rpc('api_log_auth', { p_action: 'LOGIN' })
      return { token: data.session.access_token, user: me }
    },
  ],
  ['GET', /^\/user$/, () => rpc('api_me')],
  [
    'POST',
    /^\/logout$/,
    async () => {
      try {
        await rpc('api_log_auth', { p_action: 'LOGOUT' })
      } finally {
        await supabase.auth.signOut({ scope: 'local' })
      }
      return ''
    },
  ],
  ['GET', /^\/notifications\/summary$/, () => rpc('api_notifications_summary')],

  // ----- vehicle requests -----
  ['GET', /^\/vehicle-requests$/, ({ params }) => rpc('api_vehicle_requests_list', { p_params: params })],
  ['POST', /^\/vehicle-requests$/, ({ body }) => rpc('api_vehicle_request_create', { p_body: body })],
  ['POST', /^\/vehicle-requests\/on-site$/, ({ body }) => rpc('api_vehicle_request_create_on_site', { p_body: body })],
  ['GET', /^\/vehicle-requests\/(\d+)$/, ({ id }) => rpc('api_vehicle_request_show', { p_id: num(id) })],
  ['PUT', /^\/vehicle-requests\/(\d+)\/edit$/, ({ id, body }) => rpc('api_vehicle_request_edit', { p_id: num(id), p_body: body })],
  ['PATCH', /^\/vehicle-requests\/(\d+)\/status$/, ({ id, body }) => rpc('api_vehicle_request_status', { p_id: num(id), p_body: body })],

  // ----- allocations -----
  ['GET', /^\/allocation-options$/, ({ params }) => rpc('api_allocation_options', { p_params: params })],
  ['GET', /^\/allocations$/, ({ params }) => rpc('api_allocations_list', { p_params: params })],
  ['POST', /^\/allocations$/, ({ body }) => rpc('api_allocation_store', { p_body: body })],
  ['PUT', /^\/allocations\/(\d+)$/, ({ id, body }) => rpc('api_allocation_update', { p_id: num(id), p_body: body })],
  ['POST', /^\/allocations\/(\d+)\/cancel$/, ({ id, body }) => rpc('api_allocation_cancel', { p_id: num(id), p_body: body })],
  [
    'GET',
    /^\/allocations\/(\d+)\/print$/,
    async ({ id }) => buildAllocationFormHtml(await rpc('api_allocation_print_data', { p_id: num(id) })),
  ],
  ['POST', /^\/allocation-drivers$/, ({ body }) => rpc('api_create_driver', { p_body: body })],
  ['POST', /^\/allocation-vehicles$/, ({ body }) => rpc('api_create_vehicle', { p_body: body })],

  // ----- date changes -----
  ['GET', /^\/reschedule-requests$/, ({ params }) => rpc('api_reschedule_list', { p_params: params })],
  ['POST', /^\/allocations\/(\d+)\/reschedule-requests$/, ({ id, body }) => rpc('api_reschedule_request_create', { p_allocation: num(id), p_body: body })],
  ['POST', /^\/allocations\/(\d+)\/reschedule$/, ({ id, body }) => rpc('api_reschedule_direct', { p_allocation: num(id), p_body: body })],
  ['POST', /^\/reschedule-requests\/(\d+)\/approve$/, ({ id, body }) => rpc('api_reschedule_approve', { p_id: num(id), p_body: body })],
  ['POST', /^\/reschedule-requests\/(\d+)\/disapprove$/, ({ id, body }) => rpc('api_reschedule_disapprove', { p_id: num(id), p_body: body })],

  // ----- sending a trip request to another administrator -----
  ['GET', /^\/admins$/, () => rpc('api_admins')],
  ['GET', /^\/trip-request-shares$/, () => rpc('api_trip_shares_list')],
  ['POST', /^\/trip-request-shares$/, ({ body }) => rpc('api_trip_share_create', { p_body: body })],

  // ----- trips and vehicles -----
  ['GET', /^\/trips$/, ({ params }) => rpc('api_trips_list', { p_params: params })],
  ['GET', /^\/my-trips$/, ({ params }) => rpc('api_my_trips', { p_params: params })],
  ['GET', /^\/trip-views$/, () => rpc('api_trip_views_list')],
  ['POST', /^\/trips\/(\d+)\/view$/, ({ id }) => rpc('api_trip_view_store', { p_trip: num(id) })],
  ['GET', /^\/vehicles$/, () => rpc('api_vehicles_list')],

  // ----- users -----
  ['GET', /^\/users$/, ({ params }) => rpc('api_users_list', { p_params: params })],
  ['POST', /^\/register$/, ({ body }) => invokeUsers({ action: 'register', data: body })],
  ['POST', /^\/admin-transfer$/, ({ body }) => invokeUsers({ action: 'transfer', data: body })],
  ['PUT', /^\/users\/(\d+)$/, ({ id, body }) => invokeUsers({ action: 'update', id: num(id), data: body })],
  ['DELETE', /^\/users\/(\d+)$/, ({ id }) => rpc('api_user_request_deletion', { p_id: num(id) })],
  ['POST', /^\/users\/(\d+)\/cancel-deletion$/, ({ id }) => rpc('api_user_cancel_deletion', { p_id: num(id) })],

  // ----- audit log -----
  ['GET', /^\/audit-logs$/, ({ params }) => rpc('api_audit_logs', { p_params: params })],

  // ----- maintenance -----
  ['GET', /^\/maintenance-logs$/, ({ params }) => rpc('api_maintenance_list', { p_params: params })],
  ['POST', /^\/maintenance-logs$/, ({ body }) => rpc('api_maintenance_create', { p_body: body })],
  ['PATCH', /^\/maintenance-logs\/(\d+)$/, ({ id, body }) => rpc('api_maintenance_update', { p_id: num(id), p_body: body })],
  ['GET', /^\/preventive-maintenance-checklists$/, ({ params }) => rpc('api_checklists_list', { p_params: params })],
  ['POST', /^\/preventive-maintenance-checklists$/, ({ body }) => rpc('api_checklist_create', { p_body: body })],
  [
    'GET',
    /^\/preventive-maintenance-checklists\/(\d+)\/print$/,
    async ({ id }) => buildChecklistHtml(await rpc('api_checklist_print_data', { p_id: num(id) })),
  ],
]

async function request(method, path, { params, data } = {}) {
  const url = path.split('?')[0]

  for (const [routeMethod, pattern, handler] of routes) {
    if (routeMethod !== method) continue

    const match = url.match(pattern)
    if (!match) continue

    try {
      const body = await handler({ id: match[1], params: clean(params), body: data ?? {} })
      return { data: body, status: 200 }
    } catch (error) {
      if (error?.response?.status === 401) await onUnauthenticated()
      throw error
    }
  }

  throw fail(404, { message: 'That endpoint does not exist.' })
}

const api = {
  get: (path, config = {}) => request('GET', path, config),
  post: (path, data, config = {}) => request('POST', path, { ...config, data }),
  put: (path, data, config = {}) => request('PUT', path, { ...config, data }),
  patch: (path, data, config = {}) => request('PATCH', path, { ...config, data }),
  delete: (path, config = {}) => request('DELETE', path, config),
}

/**
 * Laravel wraps top-level JsonResource responses in `data`, but nested
 * resources (e.g. login's `user` key) and plain json() payloads are not.
 */
export function unwrap(response) {
  const payload = response?.data
  if (payload && typeof payload === 'object' && 'data' in payload && !Array.isArray(payload)) {
    return payload.data
  }
  return payload
}

/** Turns a 422 response into a { field: 'first message' } map. */
export function validationErrors(error) {
  const errors = error?.response?.data?.errors
  if (!errors) return {}

  return Object.fromEntries(
    Object.entries(errors).map(([field, messages]) => [field, messages[0]]),
  )
}

export function errorMessage(error, fallback = 'Something went wrong. Please try again.') {
  return error?.response?.data?.message ?? fallback
}

export default api