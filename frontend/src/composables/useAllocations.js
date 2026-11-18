import { computed, onMounted, ref } from 'vue'
import api, { errorMessage, unwrap } from '@/lib/api'
import { useAuthStore } from '@/stores/auth'
import { todayIso } from '@/lib/format'
import { ACTIVE_STATUSES, findConflicts, resourceState } from '@/lib/allocations'

/**
 * Data for the allocation pages.
 * Faculty get their own allocations and date change requests.
 * Administrators and staff also get the vehicle and driver lists.
 */
export function useAllocations() {
  const auth = useAuthStore()

  // Administrators and staff use the full allocation page.
  const canManage = computed(() => auth.isAdministrator || auth.isStaff)

  const allocations = ref([])
  const dateChanges = ref([])

  // Administrators and staff only
  const vehicles = ref([])
  const drivers = ref([])
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

      if (canManage.value) {
        calls.push(
          api.get('/allocation-options', {
            params: { skip_completion: 1 },
          }),
          api.get('/admins'),
        )
      }

      const [changeRows, options, adminRows] = (await Promise.all(calls)).map(unwrap)

      allocations.value = allocationRows
      dateChanges.value = changeRows

      if (canManage.value) {
        vehicles.value = options.vehicles
        drivers.value = options.drivers
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
    const result = { scheduled: 0, in_progress: 0, completed: 0, cancelled: 0 }
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

  /* ================= CONFLICTS (administrators and staff) ================= */

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

  /* ================= SUMMARY (administrators and staff) ================= */

  // Only trips with an allocation belong on this page.
  const summaryRows = computed(() => {
    const fromAllocation = (allocation, extra) => ({
      allocation,
      requestId: allocation.vehicle_request?.id,
      destination: allocation.trip?.destination,
      requester: allocation.vehicle_request?.requester,
      bookingSource: allocation.vehicle_request?.booking_source,
      requesterDepartment: allocation.vehicle_request?.requester_department,
      requesterContact: allocation.vehicle_request?.requester_contact,
      // The trip type is the one the faculty member chose on the request form.
      tripType: allocation.vehicle_request?.trip_type,
      passengers: allocation.vehicle_request?.number_of_passengers,
      date: allocation.trip?.trip_date,
      time: allocation.trip?.departure_time,
      ...extra,
    })

    return allocations.value.map((allocation) =>
      fromAllocation(allocation, { key: `a${allocation.id}`, kind: 'allocation' }),
    )
  })

  return {
    allocations,
    dateChanges,
    vehicles,
    drivers,
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