import { computed, onMounted, ref } from 'vue'
import api, { errorMessage } from '@/lib/api'
import { formatDate, formatTime, parseDate, toDateString, TRIP_TYPE_LABELS } from '@/lib/format'
import {
  dateIsWithinTrip,
  driverContact,
  driverName,
  getTripEndDate,
  getTripStartDate,
  isScheduledTrip,
  rangesOverlap,
  requesterName,
  tripDateRange,
  tripType,
  vehicleName,
} from '@/lib/trips'

const VIEWED_KEY = 'campusglide_trip_schedule_viewed'

function getStoredIds(key) {
  try {
    const value = JSON.parse(localStorage.getItem(key) || '[]')
    return Array.isArray(value) ? value.map(Number) : []
  } catch {
    return []
  }
}

function storeIds(key, ids) {
  localStorage.setItem(key, JSON.stringify([...new Set(ids.map(Number))]))
}

function getSunday(date) {
  const result = new Date(date)
  result.setHours(0, 0, 0, 0)
  result.setDate(result.getDate() - result.getDay())
  return result
}

function monthShort(date) {
  return date.toLocaleString('en-PH', { month: 'short' })
}

export function useTripSchedule() {
  const currentView = ref('month')
  const currentTripType = ref('inclusive')
  const currentDate = ref(new Date())
  const selectedDate = ref('')
  const weekStart = ref(getSunday(new Date()))
  const scheduledTrips = ref([])
  const activeTrip = ref(null)
  const activeTrips = ref([])
  const activeDateLabel = ref('')
  const loading = ref(false)
  const loadError = ref('')

  const viewedIds = ref(getStoredIds(VIEWED_KEY))

  const currentTripTypeLabel = computed(() => TRIP_TYPE_LABELS[currentTripType.value])

  /* ================= DATA ================= */

  async function fetchTrips() {
    loading.value = true
    loadError.value = ''
    try {
      const { data: payload } = await api.get('/trips')
      const rows = Array.isArray(payload)
        ? payload
        : Array.isArray(payload?.data)
          ? payload.data
          : Array.isArray(payload?.trips)
            ? payload.trips
            : null

      if (!rows) {
        loadError.value = 'The trips API returned an unexpected response format.'
        return
      }

      scheduledTrips.value = rows.map((trip) => ({
        ...trip,
        vehicle_request: trip?.vehicle_request || trip?.vehicleRequest || null,
      }))

      const invalidTypeTrips = scheduledTrips.value.filter((trip) => !tripType(trip))
      if (invalidTypeTrips.length) {
        console.warn(
          'Trip Schedule: trips excluded because their vehicle request has no valid trip_type:',
          invalidTypeTrips.map((trip) => trip.id),
        )
      }
    } catch (error) {
      console.error(error)
      loadError.value = errorMessage(error, 'Unable to load scheduled trips.')
    } finally {
      loading.value = false
    }
  }

  const filteredTrips = computed(() =>
    scheduledTrips.value.filter((trip) => {
      const type = tripType(trip)
      return isScheduledTrip(trip) && type !== null && type === currentTripType.value
    }),
  )

  const scheduledTripList = computed(() =>
    [...filteredTrips.value].sort(
      (a, b) => parseDate(getTripStartDate(a)) - parseDate(getTripStartDate(b)),
    ),
  )

  const upcomingTripCount = computed(() => {
    const today = parseDate(toDateString(new Date()))
    return filteredTrips.value.filter((trip) => parseDate(getTripEndDate(trip)) >= today).length
  })

  const newTripCount = computed(() => filteredTrips.value.filter(isNewTrip).length)

  onMounted(fetchTrips)

  function isNewTrip(trip) {
    return !viewedIds.value.includes(Number(trip?.id))
  }

  function markTripViewed(trip) {
    if (!trip?.id) return
    if (!viewedIds.value.includes(Number(trip.id))) {
      viewedIds.value = [...viewedIds.value, Number(trip.id)]
      storeIds(VIEWED_KEY, viewedIds.value)
    }
  }

  /* ================= MONTH ================= */

  const monthName = computed(() =>
    currentDate.value.toLocaleString('en-PH', { month: 'long' }),
  )
  const daysInMonth = computed(() =>
    new Date(currentDate.value.getFullYear(), currentDate.value.getMonth() + 1, 0).getDate(),
  )
  const firstDayOfMonth = computed(() =>
    new Date(currentDate.value.getFullYear(), currentDate.value.getMonth(), 1).getDay(),
  )

  function dateForDay(day) {
    return toDateString(
      new Date(currentDate.value.getFullYear(), currentDate.value.getMonth(), day),
    )
  }

  function changeMonth(offset) {
    currentDate.value = new Date(
      currentDate.value.getFullYear(),
      currentDate.value.getMonth() + offset,
      1,
    )
  }

  function isToday(day) {
    return dateForDay(day) === toDateString(new Date())
  }

  function isSelectedDate(day) {
    return dateForDay(day) === selectedDate.value
  }

  function getTripsForDate(date) {
    return filteredTrips.value.filter((trip) => dateIsWithinTrip(date, trip))
  }

  function isScheduled(day) {
    return getTripsForDate(dateForDay(day)).length > 0
  }

  function hasNewTripOnDate(day) {
    return getTripsForDate(dateForDay(day)).some(isNewTrip)
  }

  function getTripCountForDate(day) {
    return getTripsForDate(dateForDay(day)).length
  }

  function openDate(date) {
    const trips = getTripsForDate(date)
    if (!trips.length) return

    activeTrips.value = trips
    activeTrip.value = trips[0]
    activeDateLabel.value = formatDate(date)
    selectedDate.value = date
    // Opening a date means the user has seen every trip listed for that date.
    trips.forEach(markTripViewed)
  }

  function openDay(day) {
    openDate(dateForDay(day))
  }

  const monthTrips = computed(() => {
    const year = currentDate.value.getFullYear()
    const month = currentDate.value.getMonth()
    const monthStart = toDateString(new Date(year, month, 1))
    const monthEnd = toDateString(new Date(year, month + 1, 0))

    return scheduledTripList.value.filter((trip) =>
      rangesOverlap(getTripStartDate(trip), getTripEndDate(trip), monthStart, monthEnd),
    )
  })

  /* ================= WEEK ================= */

  const weekDays = computed(() =>
    Array.from({ length: 7 }, (_, i) => {
      const date = new Date(weekStart.value)
      date.setDate(weekStart.value.getDate() + i)
      return {
        date: toDateString(date),
        number: date.getDate(),
        name: date.toLocaleDateString('en-PH', { weekday: 'short' }),
      }
    }),
  )

  const weekRange = computed(() => {
    const start = weekStart.value
    const end = new Date(start)
    end.setDate(start.getDate() + 6)
    const endLabel =
      start.getMonth() === end.getMonth() ? end.getDate() : `${monthShort(end)} ${end.getDate()}`
    return `${monthShort(start)} ${start.getDate()}–${endLabel}, ${end.getFullYear()}`
  })

  function changeWeek(offset) {
    const date = new Date(weekStart.value)
    date.setDate(date.getDate() + offset * 7)
    weekStart.value = getSunday(date)
  }

  /* ================= MODAL ================= */

  function openTripModal(trip) {
    if (!trip) return
    activeTrips.value = [trip]
    activeTrip.value = trip
    activeDateLabel.value = tripDateRange(trip)
    markTripViewed(trip)
  }

  function selectModalTrip(trip) {
    if (!trip) return
    activeTrip.value = trip
    markTripViewed(trip)
  }

  function closeTripModal() {
    activeTrip.value = null
    activeTrips.value = []
    activeDateLabel.value = ''
  }

  const tripDetailRows = computed(() => {
    const trip = activeTrip.value
    if (!trip) return []

    return [
      { label: 'Trip type', value: TRIP_TYPE_LABELS[tripType(trip)] ?? 'Unknown type' },
      { label: 'Requester', value: requesterName(trip) },
      { label: 'Date', value: tripDateRange(trip) },
      { label: 'Departure', value: formatTime(trip.departure_time) },
      { label: 'Estimated return', value: formatTime(trip.estimated_return_time) },
      { label: 'Vehicle', value: vehicleName(trip) },
      { label: 'Driver', value: driverName(trip) },
      { label: 'Driver contact', value: driverContact(trip) },
      { label: 'Destination', value: trip.destination || '—' },
      { label: 'Purpose', value: trip.purpose || '—' },
      { label: 'Passengers', value: trip.vehicle_request?.number_of_passengers ?? '—' },
    ]
  })

  return {
    currentView,
    currentTripType,
    currentDate,
    activeTrip,
    activeTrips,
    activeDateLabel,
    loading,
    loadError,
    currentTripTypeLabel,
    filteredTrips,
    scheduledTripList,
    upcomingTripCount,
    newTripCount,
    monthName,
    daysInMonth,
    firstDayOfMonth,
    weekDays,
    weekRange,
    monthTrips,
    tripDetailRows,
    fetchTrips,
    changeMonth,
    changeWeek,
    isToday,
    isSelectedDate,
    isScheduled,
    getTripCountForDate,
    hasNewTripOnDate,
    getTripsForDate,
    openDay,
    openDate,
    openTripModal,
    selectModalTrip,
    closeTripModal,
    isNewTrip,
  }
}