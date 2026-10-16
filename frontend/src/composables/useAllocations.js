import { computed, onMounted, ref } from 'vue'
import api, { errorMessage, unwrap } from '@/lib/api'
import { useAuthStore } from '@/stores/auth'
import { todayIso } from '@/lib/format'
import { ACTIVE_STATUSES, findConflicts, resourceState } from '@/lib/allocations'

// Order of the summary list: needs allocation, in progress, scheduled, completed.
const ROW_ORDER = { waiting: 0, in_progress: 1, scheduled: 2, completed: 3 }

function rowGroup(row) {
  if (row.kind === 'waiting') return 'waiting'
  return row.allocation?.status ?? 'scheduled'
}

/**
 * Data for the allocation pages.
 * Faculty get their own allocations and date change requests.
 * Administrators also get the approved requests that need a vehicle and driver,
 * the vehicle and driver lists, and the trip requests sent to them.
 */
export function useAllocations() {
  const auth = useAuthStore()

  const allocations = ref([])
  const dateChanges = ref([])

  // Administrators only
  const waiting = ref([])
  const vehicles = ref([])
  const drivers = ref([])
  const shares = ref([])
  const admins = ref([])

  const loading = ref(true)
  const loadError = ref('')

  /* ================= DATA ================= */

  async function load() {
    loading.value = true
    loadError.value = ''

    try {
      // The allocation list goes first. The backend also marks finished trips as completed
      // on this call, so the other lists below already show the updated status.
      const allocationRows = unwrap(await api.get('/allocations', { params: { per_page: 100 } }))

      const calls = [api.get('/reschedule-requests')]

      if (auth.isAdministrator) {
        calls.push(
          api.get('/allocation-options'),
          api.get('/trip-request-shares'),
          api.get('/admins'),
        )
      }

      const [changeRows, options, shareRows, adminRows] = (await Promise.all(calls)).map(unwrap)

      allocations.value = allocationRows
      dateChanges.value = changeRows

      if (auth.isAdministrator) {
        waiting.value = options.requests
        vehicles.value = options.vehicles
        drivers.value = options.drivers
        shares.value = shareRows
        admins.value = adminRows
      }
    } catch (error) {
      loadError.value = errorMessage(error, 'Unable to load allocations.')
    } finally {
      loading.value = false
    }
  }

  onMounted(load)

  // A vehicle or driver added from the allocation page shows up in the lists right away.
  function addVehicle(vehicle) {
    vehicles.value = [...vehicles.value, vehicle]
  }

  function addDriver(driver) {
    drivers.value = [...drivers.value, driver]
  }

  /* ================= DERIVED DATA ================= */

  const activeAllocations = computed(() =>
    allocations.value.filter((allocation) => ACTIVE_STATUSES.includes(allocation.status)),
  )

  const counts = computed(() => {
    const result = { scheduled: 0, in_progress: 0, completed: 0 }
    allocations.value.forEach((allocation) => {
      if (result[allocation.status] !== undefined) result[allocation.status]++
    })
    return result
  })

  const pendingDateChanges = computed(() =>
    dateChanges.value.filter((item) => item.status === 'pending'),
  )

  // allocation id -> its pending date change request
  const pendingByAllocation = computed(() =>
    Object.fromEntries(pendingDateChanges.value.map((item) => [item.allocation_id, item])),
  )

  /* ================= CONFLICTS (administrators) ================= */

  const conflicts = computed(() => findConflicts(activeAllocations.value))

  const conflictedAllocations = computed(() =>
    allocations.value.filter((allocation) => conflicts.value[allocation.id]),
  )

  const conflictTexts = computed(() => [
    ...new Set(conflictedAllocations.value.map((allocation) => conflicts.value[allocation.id].text)),
  ])

  // Availability is checked for today:
  // red = on a trip now (in progress), orange = has a scheduled trip today, green = available.
  const vehicleList = computed(() => {
    const today = todayIso()
    return vehicles.value.map((vehicle) => ({
      ...vehicle,
      state: resourceState('vehicle', vehicle.id, activeAllocations.value, today),
    }))
  })

  const driverList = computed(() => {
    const today = todayIso()
    return drivers.value.map((driver) => ({
      ...driver,
      state: resourceState('driver', driver.id, activeAllocations.value, today),
    }))
  })

  /* ================= SUMMARY (administrators) ================= */

  // One list for the summary: allocations, approved requests that still need
  // a vehicle and driver, and trip requests sent by other administrators.
  // Sorted by group: needs allocation, in progress, scheduled, completed.
  // Inside a group, the soonest date comes first. Completed trips show the newest first.
  const summaryRows = computed(() => {
    const fromAllocation = (allocation, extra) => ({
      allocation,
      requestId: allocation.vehicle_request?.id,
      destination: allocation.trip?.destination,
      requester: allocation.vehicle_request?.requester,
      // The trip type is the one the faculty member chose on the request form.
      tripType: allocation.vehicle_request?.trip_type,
      passengers: allocation.vehicle_request?.number_of_passengers,
      date: allocation.trip?.trip_date,
      time: allocation.trip?.departure_time,
      ...extra,
    })

    const rows = [
      ...allocations.value.map((allocation) =>
        fromAllocation(allocation, { key: `a${allocation.id}`, kind: 'allocation' }),
      ),
      ...waiting.value.map((request) => ({
        key: `r${request.id}`,
        kind: 'waiting',
        request,
        requestId: request.id,
        destination: request.destination,
        requester: request.requester,
        tripType: request.trip_type,
        passengers: request.number_of_passengers,
        date: request.trip_date,
        time: request.departure_time,
      })),
      ...shares.value.map((share) =>
        fromAllocation(share.allocation, { key: `s${share.id}`, kind: 'received', share }),
      ),
    ]

    return rows.sort((x, y) => {
      const groupX = rowGroup(x)
      const groupY = rowGroup(y)

      const byGroup = (ROW_ORDER[groupX] ?? 4) - (ROW_ORDER[groupY] ?? 4)
      if (byGroup !== 0) return byGroup

      const byDate = `${x.date ?? ''} ${x.time ?? ''}`.localeCompare(`${y.date ?? ''} ${y.time ?? ''}`)
      return groupX === 'completed' ? -byDate : byDate
    })
  })

  return {
    allocations,
    dateChanges,
    waiting,
    vehicles,
    drivers,
    shares,
    admins,
    loading,
    loadError,
    activeAllocations,
    counts,
    pendingDateChanges,
    pendingByAllocation,
    conflicts,
    conflictedAllocations,
    conflictTexts,
    vehicleList,
    driverList,
    summaryRows,
    load,
    addVehicle,
    addDriver,
  }
}