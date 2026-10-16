import { formatDate, formatTime, parseDate, toDateString } from '@/lib/format'

/** Trip statuses that still block a vehicle or driver. */
export const ACTIVE_STATUSES = ['scheduled', 'in_progress']

// First and last day of a trip. A one-day trip ends on the day it starts.
function tripRange(allocation) {
  const start = allocation.trip?.trip_date
  const end = allocation.trip?.trip_end_date || start
  return { start, end }
}

// Two trips overlap when they share at least one day.
function overlaps(a, b) {
  const first = tripRange(a)
  const second = tripRange(b)
  if (!first.start || !second.start) return false

  return first.start <= second.end && second.start <= first.end
}

/**
 * Finds active allocations that share a driver or a vehicle on the same day(s).
 * Returns { [allocationId]: { text, driverId, vehicleId } }.
 */
export function findConflicts(allocations) {
  const map = {}

  for (let i = 0; i < allocations.length; i++) {
    for (let j = i + 1; j < allocations.length; j++) {
      const a = allocations[i]
      const b = allocations[j]
      if (!overlaps(a, b)) continue

      const sameDriver = a.driver?.id && a.driver.id === b.driver?.id
      const sameVehicle = a.vehicle?.id && a.vehicle.id === b.vehicle?.id
      if (!sameDriver && !sameVehicle) continue

      const who = sameDriver ? a.driver.name : a.vehicle.vehicle_model
      const text = `${who} is assigned to 2 trips on ${formatDate(a.trip.trip_date)}`

      for (const item of [a, b]) {
        const entry = (map[item.id] ??= { text, driverId: null, vehicleId: null })
        if (sameDriver) entry.driverId = a.driver.id
        if (sameVehicle) entry.vehicleId = a.vehicle.id
      }
    }
  }

  return map
}

/**
 * State of a vehicle or driver on the allocation page, for TODAY.
 * green = available
 * orange = has a scheduled trip today (the trip's dates include today)
 * red = on a trip right now (in progress)
 * @param {'vehicle'|'driver'} kind
 * @param {string} today "YYYY-MM-DD"
 */
export function resourceState(kind, id, activeAllocations, today) {
  const own = activeAllocations.filter((allocation) => allocation[kind]?.id === id)

  if (own.some((allocation) => allocation.status === 'in_progress')) return 'red'

  const scheduledToday = own.some((allocation) => {
    const { start, end } = tripRange(allocation)
    return Boolean(start) && start <= today && today <= end
  })

  return scheduledToday ? 'orange' : 'green'
}

/**
 * Turns the vehicle or driver list from /allocation-options into dropdown options.
 * Unavailable ones stay in the list but cannot be picked, and show the reason.
 */
export function availabilityOptions(items) {
  return items.map((item) => ({
    value: item.id,
    label:
      item.available === false
        ? `${item.label} — Unavailable (${item.unavailable_reason})`
        : item.label,
    disabled: item.available === false,
  }))
}

/**
 * The date range of a trip when it starts on `newStart` instead.
 * The end date moves by the same number of days.
 */
export function shiftedRange(start, end, newStart) {
  const shift = Math.round((parseDate(newStart) - parseDate(start)) / 86400000)
  const last = parseDate(end || start)
  last.setDate(last.getDate() + shift)

  return { start: newStart, end: toDateString(last) }
}

/** "Oct 12, 2026 · 7:30 AM" */
export function whenText(date, time) {
  return `${date ? formatDate(date) : '—'}${time ? ` · ${formatTime(time)}` : ''}`
}

/** 7 -> "REQ-007" */
export function requestNumber(id) {
  return `REQ-${String(id).padStart(3, '0')}`
}

/** 1 -> "1 passenger", 5 -> "5 passengers", missing -> "—" */
export function passengerText(count) {
  if (count === null || count === undefined || count === '') return '—'
  return `${count} ${Number(count) === 1 ? 'passenger' : 'passengers'}`
}

/**
 * The conflicts the backend sends with a 422 response, as a list, or null.
 * One response can hold a vehicle conflict and a driver conflict together.
 */
export function conflictOf(error) {
  if (error?.response?.status !== 422) return null

  const data = error.response.data
  if (Array.isArray(data?.conflicts) && data.conflicts.length) return data.conflicts
  if (data?.conflict) return [data.conflict]

  return null
}

/**
 * A trip request can be printed only for an approved request
 * that has a vehicle and a driver assigned. The backend checks this too.
 */
export function canPrint(allocation) {
  return (
    allocation?.vehicle_request?.status === 'approved' &&
    Boolean(allocation.vehicle?.id) &&
    Boolean(allocation.driver?.id)
  )
}

/**
 * Reassign is for scheduled trips only. A trip that is in progress or
 * completed can no longer be reassigned.
 */
export function canReassign(allocation) {
  return allocation?.status === 'scheduled'
}