const LOCALE = 'en-PH'
const DATE_OPTIONS = { year: 'numeric', month: 'short', day: 'numeric' }

/** Local date as "YYYY-MM-DD". (toISOString shifts the day for users ahead of UTC.) */
export function toDateString(date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function todayIso() {
  return toDateString(new Date())
}

/** "YYYY-MM-DD" (or a longer ISO string) -> Date at local midnight. */
export function parseDate(value) {
  if (!value) return new Date(NaN)
  const [year, month, day] = String(value).slice(0, 10).split('-').map(Number)
  return new Date(year, month - 1, day)
}

export function formatDate(value) {
  if (!value) return '—'
  const date = new Date(value.length <= 10 ? `${value}T00:00:00` : value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleDateString(LOCALE, DATE_OPTIONS)
}

export function formatDateRange(start, end) {
  if (!start) return '—'
  if (!end || start === end) return formatDate(start)
  return `${formatDate(start)} – ${formatDate(end)}`
}

export function formatDateTime(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleString(LOCALE, { ...DATE_OPTIONS, hour: 'numeric', minute: '2-digit' })
}

/** API returns times as "H:i" or "H:i:s". */
export function formatTime(value) {
  if (!value) return '—'
  const [hours, minutes] = String(value).split(':')
  const date = new Date()
  date.setHours(Number(hours), Number(minutes ?? 0), 0, 0)
  return date.toLocaleTimeString(LOCALE, { hour: 'numeric', minute: '2-digit' })
}

/** Normalises "07:30:00" -> "07:30" for <input type="time"> and H:i validation. */
export function toTimeInput(value) {
  if (!value) return ''
  return String(value).slice(0, 5)
}

export function dayOfMonth(value) {
  return parseDate(value).getDate()
}

export function shortMonth(value) {
  return parseDate(value).toLocaleString(LOCALE, { month: 'short' })
}

export function initials(name = '') {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join('')
}

/** "First Last" from an object with first_name and last_name. Returns '' when empty. */
export function fullName(person) {
  return [person?.first_name, person?.last_name].filter(Boolean).join(' ')
}

export function formatKm(value) {
  return value === null || value === undefined ? '—' : `${Number(value).toLocaleString(LOCALE)} km`
}

const money = new Intl.NumberFormat(LOCALE, {
  style: 'currency',
  currency: 'PHP',
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
})

export function formatMoney(value) {
  return value === null || value === undefined ? '—' : money.format(value)
}

export const ROLE_LABELS = {
  administrator: 'Administrator',
  faculty: 'Faculty',
}

export const TRIP_TYPE_LABELS = {
  inclusive: 'Inclusive',
  exclusive: 'Exclusive',
}

export const STATUS_LABELS = {
  // Vehicle requests
  pending: 'Pending',
  approved: 'Approved',
  disapproved: 'Disapproved',
  // Trips
  scheduled: 'Scheduled',
  in_progress: 'In progress',
  // Maintenance
  upcoming: 'Upcoming',
  overdue: 'Overdue',
  completed: 'Completed',
  cancelled: 'Cancelled',
}

export const MAINTENANCE_TYPES = [
  { value: 'oil_change', label: 'Oil change' },
  { value: 'repair', label: 'Repair' },
  { value: 'refueling', label: 'Refueling' },
  { value: 'inspection', label: 'Inspection' },
  { value: 'tire_service', label: 'Tire service' },
  { value: 'other', label: 'Other' },
]