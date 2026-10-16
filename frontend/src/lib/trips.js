import { formatDateRange, fullName } from '@/lib/format'

const TRIP_TYPES = ['inclusive', 'exclusive']

// The backend (TripResource) sends the request as `vehicle_request`.
function requestOf(trip) {
  return trip?.vehicle_request ?? null
}

/** Returns 'inclusive', 'exclusive', or null. Missing values are never treated as Inclusive. */
export function tripType(trip) {
  const type = String(requestOf(trip)?.trip_type || '')
    .trim()
    .toLowerCase()
  return TRIP_TYPES.includes(type) ? type : null
}

/** Trip Schedule only shows active trips that belong to approved requests. */
export function isScheduledTrip(trip) {
  const activeStatus = ['scheduled', 'in_progress'].includes(
    String(trip?.trip_status || '').toLowerCase(),
  )
  if (!activeStatus) return false

  const request = requestOf(trip)
  return Boolean(request && String(request.status || '').toLowerCase() === 'approved')
}

export function getTripStartDate(trip) {
  return String(trip?.trip_date || requestOf(trip)?.trip_date || '').slice(0, 10)
}

// The end date is kept on the vehicle request, not on the trip.
export function getTripEndDate(trip) {
  return String(requestOf(trip)?.trip_end_date || getTripStartDate(trip)).slice(0, 10)
}

export function dateIsWithinTrip(date, trip) {
  const start = getTripStartDate(trip)
  const end = getTripEndDate(trip)
  return Boolean(start) && date >= start && date <= end
}

export function rangesOverlap(startA, endA, startB, endB) {
  return startA <= endB && endA >= startB
}

export function tripDateRange(trip) {
  return formatDateRange(getTripStartDate(trip), getTripEndDate(trip))
}

export function requesterName(trip) {
  return fullName(requestOf(trip)?.requester) || 'Approved trip'
}

export function vehicleName(trip) {
  const vehicle = trip?.vehicle
  if (!vehicle) return '—'
  return [vehicle.vehicle_model, vehicle.plate_number].filter(Boolean).join(' - ') || '—'
}

// A driver is a record only (no login), so the name is on the driver itself.
export function driverName(trip) {
  const driver = trip?.driver
  return driver?.name || fullName(driver) || '—'
}

export function driverContact(trip) {
  return trip?.driver?.contact_number || '—'
}