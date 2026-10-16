import { supabase } from '@/lib/supabase'
import { checklistHtml, vehicleRequestHtml } from '@/lib/printTemplates'

/**
 * Data layer. The components still call `api.get('/allocations')`, `api.post(...)` and so on,
 * but the calls are answered by Supabase (tables, RPC functions and the register-user function)
 * instead of the Laravel API. Responses and errors keep the axios shape the components expect:
 *   success -> { data }          (list endpoints return { data: [...] }, as Laravel resources did)
 *   failure -> error.response = { status, data: { message, errors?, conflict?, conflicts? } }
 */

/* ================= HELPERS USED BY THE COMPONENTS ================= */

/** Resources are wrapped in `data`; plain payloads are not. */
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
    Object.entries(errors).map(([field, messages]) => [
      field,
      Array.isArray(messages) ? messages[0] : messages,
    ]),
  )
}

export function errorMessage(error, fallback = 'Something went wrong. Please try again.') {
  return error?.response?.data?.message ?? fallback
}

/** Builds an error in the shape the components read. `errors` is { field: [message] }. */
export function httpError(status, message, errors) {
  const error = new Error(message)
  error.response = { status, data: { message, ...(errors ? { errors } : {}) } }
  return error
}

/* ================= ERROR CONVERSION ================= */

// PostgREST turns SQLSTATE 'PTnnn' into HTTP status nnn. `details` holds the JSON the SQL
// functions put in `detail` ({ errors, conflict, conflicts }).
function toApiError(error, status) {
  const pt = /^PT(\d{3})$/.exec(error?.code ?? '')

  // No HTTP status: the network failed. Let the component show its own fallback message.
  if (!status && !pt) return new Error(error?.message || 'Network error')

  let extra = {}
  if (error.details) {
    try {
      const parsed = JSON.parse(error.details)
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) extra = parsed
    } catch {
      // `details` is plain text: ignore it
    }
  }

  const code = status || Number(pt[1])

  // Expired or invalid session: sign out. main.js sends the user to /login.
  if (code === 401) supabase.auth.signOut()

  const result = new Error(error.message)
  result.response = { status: code, data: { message: error.message, ...extra } }
  return result
}

function check({ data, error, status }) {
  if (error) throw toApiError(error, status)
  return data
}

async function rpc(fn, args) {
  return check(await supabase.rpc(fn, args))
}

async function functionsError(error) {
  const response = error?.context
  if (!response || typeof response.status !== 'number') return new Error(error?.message || 'Network error')

  let body = {}
  try {
    body = await response.json()
  } catch {
    // not JSON
  }

  if (response.status === 401) supabase.auth.signOut()
  return httpError(response.status, body.message ?? error.message, body.errors)
}

/* ================= ROW SHAPES ================= */

const PAGE_SIZE = 10

const REQUESTER = 'requester:profiles!requester_id(id, first_name, last_name, full_name)'
const TRIP_REQUEST = `*, vehicle_request:vehicle_requests!vehicle_request_id(*, ${REQUESTER})`
const TRIP_SELECT = `${TRIP_REQUEST}, vehicle:vehicles!vehicle_id(*), driver:drivers!driver_id(*)`
const ALLOCATION_SELECT = `*, trip:trips!trip_id(${TRIP_REQUEST}), vehicle:vehicles!vehicle_id(*), driver:drivers!driver_id(*)`
const REQUEST_SELECT =
  '*, requested_by:profiles!requester_id(id, first_name, last_name, full_name, email, position)'
const LOG_SELECT = '*, vehicle:vehicles!vehicle_id(id, plate_number, vehicle_model, mileage)'

const personName = (person) =>
  person?.full_name || [person?.first_name, person?.last_name].filter(Boolean).join(' ') || null

// A driver is a record only. The components read `name`.
function toDriver(driver) {
  return driver ? { ...driver, name: personName(driver) } : null
}

function toTrip(trip) {
  return { ...trip, driver: toDriver(trip.driver) }
}

// The shape the allocation pages use: the trip status is the allocation `status`,
// and the end date of the trip comes from its vehicle request.
function toAllocation(row) {
  if (!row) return null

  const trip = row.trip
  const request = trip?.vehicle_request

  return {
    id: row.id,
    trip_id: row.trip_id,
    status: trip?.trip_status ?? 'scheduled',
    notes: row.notes,
    allocation_date: row.allocation_date,
    trip: trip
      ? {
          id: trip.id,
          trip_date: trip.trip_date,
          trip_end_date: request?.trip_end_date ?? trip.trip_date,
          departure_time: trip.departure_time,
          estimated_return_time: trip.estimated_return_time,
          destination: trip.destination,
          purpose: trip.purpose,
          trip_status: trip.trip_status,
        }
      : null,
    vehicle_request: request
      ? {
          id: request.id,
          status: request.status,
          trip_type: request.trip_type,
          trip_date: request.trip_date,
          trip_end_date: request.trip_end_date,
          number_of_passengers: request.number_of_passengers,
          requester: personName(request.requester),
        }
      : null,
    vehicle: row.vehicle,
    driver: toDriver(row.driver),
  }
}

// `requested_by` is the person (first_name / last_name). `return_time` is the old API name.
function toRequest(row, requester) {
  return {
    ...row,
    requested_by: requester ?? row.requested_by ?? null,
    return_time: row.estimated_return_time,
  }
}

const one = (value) => (Array.isArray(value) ? value[0] : value)

// API names `type` and `date_performed` are the columns maintenance_type and maintenance_date.
const LOG_COLUMNS = { type: 'maintenance_type', date_performed: 'maintenance_date' }

const toLog = (row) => ({ ...row, type: row.maintenance_type, date_performed: row.maintenance_date })

function toLogColumns(body) {
  return Object.fromEntries(
    Object.entries(body ?? {})
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => [LOG_COLUMNS[key] ?? key, value]),
  )
}

async function currentUserId() {
  const { data } = await supabase.auth.getSession()
  return data.session?.user?.id ?? null
}

// Marks finished trips as completed and frees their vehicle and driver.
// Called before listing trips and allocations. A failure here must not break the page.
async function completeFinishedTrips() {
  try {
    await supabase.rpc('complete_finished_trips')
  } catch {
    // ignore
  }
}

// Same checks as the Laravel form request, so the form shows field errors.
function validateRequestBody(b) {
  const errors = {}
  const need = (field, label) => {
    if (b[field] === undefined || b[field] === null || String(b[field]).trim() === '') {
      errors[field] = [`The ${label} field is required.`]
    }
  }

  need('destination', 'destination')
  need('purpose', 'purpose')
  need('trip_date', 'trip date')
  need('trip_end_date', 'trip end date')
  need('departure_time', 'departure time')
  need('estimated_return_time', 'estimated return time')
  need('passengers', 'passengers')

  if (!['inclusive', 'exclusive'].includes(b.trip_type)) {
    errors.trip_type = ['The selected trip type is invalid.']
  }
  if (!errors.trip_date && !errors.trip_end_date && b.trip_end_date < b.trip_date) {
    errors.trip_end_date = ['The trip end date must be on or after the trip date.']
  }
  if (
    !errors.departure_time &&
    !errors.estimated_return_time &&
    String(b.estimated_return_time).slice(0, 5) <= String(b.departure_time).slice(0, 5)
  ) {
    errors.estimated_return_time = ['The estimated return time must be after the departure time.']
  }

  const count = Number(b.number_of_passengers)
  if (!Number.isInteger(count) || count < 1) {
    errors.number_of_passengers = ['The number of passengers must be at least 1.']
  }

  if (Object.keys(errors).length) {
    throw httpError(422, Object.values(errors)[0][0], errors)
  }
}

/* ================= ROUTES ================= */

const routes = []

function route(method, path, handler) {
  const keys = []
  const pattern = path.replace(/:([a-z_]+)/g, (_, key) => {
    keys.push(key)
    return '([^/]+)'
  })
  routes.push({ method, re: new RegExp(`^${pattern}$`), keys, handler })
}

/* ---------- register (Edge Function) ---------- */

route('POST', '/register', async ({ body }) => {
  const { data, error } = await supabase.functions.invoke('register-user', { body })
  if (error) throw await functionsError(error)
  return data
})

/* ---------- vehicle requests ---------- */

// Pending first (soonest travel date on top), then the rest newest first.
route('GET', '/vehicle-requests/approved', async () => {
  const rows = check(
    await supabase
      .from('vehicle_requests')
      .select('id, trip:trips!vehicle_request_id(id)')
      .eq('status', 'approved'),
  )

  // Approved requests that do not have a trip yet need an allocation.
  return { data: rows.filter((row) => !one(row.trip)).map(({ id }) => ({ id })) }
})

route('GET', '/vehicle-requests', async ({ query }) => {
  const requested = Math.max(1, Number(query.page) || 1)

  const fetchPage = (page) => {
    let request = supabase.from('vehicle_requests_ordered').select('*', { count: 'exact' })
    if (query.status) request = request.eq('status', query.status)
    if (query.trip_type) request = request.eq('trip_type', query.trip_type)

    return request
      .order('sort_group', { ascending: true })
      .order('pending_trip_date', { ascending: true })
      .order('pending_departure_time', { ascending: true })
      .order('created_at', { ascending: false })
      .order('id', { ascending: false })
      .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1)
  }

  let page = requested
  let result = await fetchPage(page)

  // The list got shorter (for example after a decision): go back to the first page.
  if (result.error?.code === 'PGRST103' && page > 1) {
    page = 1
    result = await fetchPage(page)
  }

  const rows = check(result)
  const total = result.count ?? rows.length

  // The requesters are loaded separately (embedding through a view is not reliable).
  const ids = [...new Set(rows.map((row) => row.requester_id).filter(Boolean))]
  const people = {}
  if (ids.length) {
    const profiles = check(
      await supabase
        .from('profiles')
        .select('id, first_name, last_name, full_name, email, position')
        .in('id', ids),
    )
    profiles.forEach((profile) => {
      people[profile.id] = profile
    })
  }

  return {
    data: rows.map((row) => toRequest(row, people[row.requester_id] ?? null)),
    meta: {
      current_page: page,
      last_page: Math.max(1, Math.ceil(total / PAGE_SIZE)),
      per_page: PAGE_SIZE,
      total,
    },
  }
})

route('GET', '/vehicle-requests/:id', async ({ params }) => {
  const row = check(
    await supabase.from('vehicle_requests').select(REQUEST_SELECT).eq('id', params.id).maybeSingle(),
  )
  if (!row) throw httpError(404, 'Vehicle request not found.')
  return { data: toRequest(row) }
})

route('POST', '/vehicle-requests', async ({ body }) => {
  validateRequestBody(body)

  // requester_id is filled in by the database (auth.uid()).
  const row = check(
    await supabase
      .from('vehicle_requests')
      .insert({
        trip_date: body.trip_date,
        trip_end_date: body.trip_end_date,
        trip_type: body.trip_type,
        departure_time: body.departure_time,
        destination: String(body.destination).trim(),
        purpose: String(body.purpose).trim(),
        estimated_return_time: body.estimated_return_time,
        passengers: String(body.passengers).trim(),
        number_of_passengers: Number(body.number_of_passengers),
      })
      .select(REQUEST_SELECT)
      .single(),
  )

  return { data: toRequest(row) }
})

route('PUT', '/vehicle-requests/:id/edit', async ({ params, body }) => {
  validateRequestBody(body)

  return rpc('edit_vehicle_request', {
    p_request_id: Number(params.id),
    p_trip_date: body.trip_date,
    p_trip_end_date: body.trip_end_date,
    p_trip_type: body.trip_type,
    p_departure_time: body.departure_time,
    p_destination: String(body.destination).trim(),
    p_purpose: String(body.purpose).trim(),
    p_estimated_return_time: body.estimated_return_time,
    p_passengers: String(body.passengers).trim(),
    p_number_of_passengers: Number(body.number_of_passengers),
    p_edit_reason: body.edit_reason ?? null,
  })
})

route('PATCH', '/vehicle-requests/:id/status', async ({ params, body }) =>
  rpc('update_vehicle_request_status', {
    p_request_id: Number(params.id),
    p_status: body.status,
    p_remarks: body.remarks ?? null,
  }),
)

/* ---------- allocations ---------- */

route('GET', '/allocations', async ({ query }) => {
  await completeFinishedTrips()

  const rows = check(
    await supabase
      .from('allocations')
      .select(ALLOCATION_SELECT)
      .order('id', { ascending: false })
      .limit(Number(query.per_page) || 100),
  )

  return { data: rows.map(toAllocation) }
})

route('GET', '/allocation-options', async ({ query }) =>
  rpc('allocation_options', {
    p_start_date: query.start_date,
    p_end_date: query.end_date,
    p_ignore_trip_id: query.ignore_trip_id,
  }),
)

route('POST', '/allocations', async ({ body }) => {
  const id = await rpc('create_allocation', {
    p_vehicle_request_id: Number(body.vehicle_request_id),
    p_vehicle_id: Number(body.vehicle_id),
    p_driver_id: Number(body.driver_id),
    p_notes: body.notes ?? null,
    p_approve_request: Boolean(body.approve_request),
  })
  return { data: { id } }
})

route('PUT', '/allocations/:id', async ({ params, body }) => {
  const id = await rpc('update_allocation', {
    p_allocation_id: Number(params.id),
    p_vehicle_id: body.vehicle_id,
    p_driver_id: body.driver_id,
    p_status: body.status,
    p_notes: body.notes,
    p_new_date: body.new_date,
    p_reason: body.reason,
  })
  return { data: { id } }
})

route('POST', '/allocation-drivers', async ({ body }) =>
  // The function answers { data: <dropdown item> }.
  rpc('add_driver', {
    p_name: body.name ?? null,
    p_contact_number: body.contact_number ?? null,
    p_license_number: body.license_number ?? null,
    p_license_expiry_date: body.license_expiry_date || null,
  }),
)

route('POST', '/allocation-vehicles', async ({ body }) =>
  rpc('add_vehicle', {
    p_plate_number: body.plate_number ?? null,
    p_vehicle_model: body.vehicle_model ?? null,
    p_capacity: body.capacity ?? null,
  }),
)

// The printable form is built here from the data the backend sends.
route('GET', '/allocations/:id/print', async ({ params }) => {
  const data = await rpc('get_vehicle_request_print', { p_allocation_id: Number(params.id) })
  return vehicleRequestHtml(data)
})

/* ---------- date changes ---------- */

route('GET', '/reschedule-requests', async ({ query }) => {
  let request = supabase
    .from('reschedule_requests')
    .select(
      '*, requester:profiles!requested_by(full_name), trip:trips!trip_id(id, destination, trip_date, allocation:allocations!trip_id(id))',
    )
    .order('created_at', { ascending: false })

  if (query.status) request = request.eq('status', query.status)

  const rows = check(await request)

  return {
    data: rows.map(({ requester, trip, ...row }) => ({
      ...row,
      requested_by: requester?.full_name ?? null,
      allocation_id: one(trip?.allocation)?.id ?? null,
      trip: trip ? { id: trip.id, destination: trip.destination, trip_date: trip.trip_date } : null,
    })),
  }
})

route('POST', '/allocations/:id/reschedule-requests', async ({ params, body }) => {
  const id = await rpc('request_reschedule', {
    p_allocation_id: Number(params.id),
    p_new_date: body.new_date || null,
    p_reason: body.reason ?? null,
  })
  return { data: { id } }
})

route('POST', '/allocations/:id/reschedule', async ({ params, body }) => {
  const id = await rpc('reschedule_trip', {
    p_allocation_id: Number(params.id),
    p_new_date: body.new_date || null,
    p_reason: body.reason ?? null,
  })
  return { data: { id } }
})

route('POST', '/reschedule-requests/:id/approve', async ({ params, body }) => {
  const id = await rpc('approve_reschedule', {
    p_request_id: Number(params.id),
    p_admin_reason: body.admin_reason ?? null,
  })
  return { data: { id } }
})

route('POST', '/reschedule-requests/:id/disapprove', async ({ params, body }) => {
  const id = await rpc('disapprove_reschedule', {
    p_request_id: Number(params.id),
    p_admin_reason: body.admin_reason ?? null,
  })
  return { data: { id } }
})

/* ---------- sharing a trip request between administrators ---------- */

// The other active administrators (the person who is signed in is left out).
route('GET', '/admins', async () => {
  const me = await currentUserId()

  const rows = check(
    await supabase
      .from('profiles')
      .select('id, full_name, email')
      .eq('role', 'administrator')
      .eq('is_active', true)
      .order('full_name'),
  )

  return {
    data: rows.filter((row) => row.id !== me).map((row) => ({ id: row.id, name: row.full_name, email: row.email })),
  }
})

// Trip requests other administrators sent to me.
route('GET', '/trip-request-shares', async () => {
  const rows = check(
    await supabase
      .from('trip_request_shares')
      .select(`*, sender:profiles!sender_id(id, full_name, email), allocation:allocations!allocation_id(${ALLOCATION_SELECT})`)
      .order('created_at', { ascending: false }),
  )

  return {
    data: rows
      .filter((row) => row.allocation)
      .map((row) => ({
        id: row.id,
        created_at: row.created_at,
        sender: { id: row.sender?.id, name: row.sender?.full_name ?? '—', email: row.sender?.email },
        allocation: toAllocation(row.allocation),
      })),
  }
})

route('POST', '/trip-request-shares', async ({ body }) => {
  // No select(): the sender is not allowed to read the row back (see shares_select).
  check(
    await supabase
      .from('trip_request_shares')
      .insert({ allocation_id: body.allocation_id, recipient_id: body.recipient_id }),
  )

  const recipient = check(
    await supabase.from('profiles').select('id, full_name').eq('id', body.recipient_id).maybeSingle(),
  )

  return { recipient: { id: body.recipient_id, name: recipient?.full_name ?? 'the administrator' } }
})

/* ---------- trips ---------- */

async function listTrips() {
  await completeFinishedTrips()

  const rows = check(
    await supabase.from('trips').select(TRIP_SELECT).order('trip_date', { ascending: true }),
  )

  return { data: rows.map(toTrip) }
}

// Administrators see every trip. Row Level Security limits faculty to their own trips.
route('GET', '/trips', listTrips)
route('GET', '/my-trips', listTrips)

/* ---------- vehicles and maintenance ---------- */

route('GET', '/vehicles', async () => ({
  data: check(await supabase.from('vehicles').select('*').order('plate_number')),
}))

route('GET', '/maintenance-logs', async () => {
  const rows = check(
    await supabase
      .from('vehicle_maintenance')
      .select(LOG_SELECT)
      .order('maintenance_date', { ascending: false }),
  )
  return { data: rows.map(toLog) }
})

route('POST', '/maintenance-logs', async ({ body }) => {
  const row = check(
    await supabase.from('vehicle_maintenance').insert(toLogColumns(body)).select(LOG_SELECT).single(),
  )
  return { data: toLog(row) }
})

route('PATCH', '/maintenance-logs/:id', async ({ params, body }) => {
  const row = check(
    await supabase
      .from('vehicle_maintenance')
      .update(toLogColumns(body))
      .eq('id', params.id)
      .select(LOG_SELECT)
      .maybeSingle(),
  )
  if (!row) throw httpError(404, 'Maintenance record not found.')
  return { data: toLog(row) }
})

route('GET', '/preventive-maintenance-checklists', async () => ({
  data: check(
    await supabase
      .from('preventive_maintenance_checklists')
      .select('*, vehicle:vehicles!vehicle_id(id, plate_number, vehicle_model)')
      .order('inspection_date', { ascending: false })
      .order('id', { ascending: false }),
  ),
}))

route('POST', '/preventive-maintenance-checklists', async ({ body }) => {
  // The form sends '' for blank dates and ratings. The database needs null.
  const columns = Object.fromEntries(
    Object.entries(body ?? {}).map(([key, value]) => [key, value === '' ? null : value]),
  )

  const row = check(
    await supabase.from('preventive_maintenance_checklists').insert(columns).select('*').single(),
  )
  return { data: row }
})

route('GET', '/preventive-maintenance-checklists/:id/print', async ({ params }) => {
  const data = await rpc('get_checklist_print', { p_checklist_id: Number(params.id) })
  return checklistHtml(data)
})

/* ================= DISPATCH ================= */

async function dispatch(method, url, { params = {}, body = {} } = {}) {
  const path = String(url).split('?')[0]

  for (const entry of routes) {
    if (entry.method !== method) continue

    const match = entry.re.exec(path)
    if (!match) continue

    const pathParams = Object.fromEntries(
      entry.keys.map((key, index) => [key, decodeURIComponent(match[index + 1])]),
    )

    const data = await entry.handler({ params: pathParams, query: params ?? {}, body: body ?? {} })
    return { data, status: 200 }
  }

  throw httpError(404, 'Not found.')
}

const api = {
  get: (url, config = {}) => dispatch('GET', url, { params: config.params }),
  post: (url, body) => dispatch('POST', url, { body }),
  put: (url, body) => dispatch('PUT', url, { body }),
  patch: (url, body) => dispatch('PATCH', url, { body }),
}

export default api