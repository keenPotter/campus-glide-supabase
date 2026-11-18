<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import api, { errorMessage } from '@/lib/api'
import { formatDate, formatTime, MONTH_OPTIONS, STATUS_LABELS, TRIP_TYPE_DESCRIPTIONS, YEAR_OPTIONS } from '@/lib/format'
import { useToast } from '@/composables/useToast'
import { driverContact, driverName, getTripStartDate, vehicleName } from '@/lib/trips'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import RefreshButton from '@/components/ui/RefreshButton.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import LoadError from '@/components/ui/LoadError.vue'

const toast = useToast()
const trips = ref([])
const paginationMeta = ref({ current_page: 1, last_page: 1, total: 0 })
const loading = ref(true)
const loadError = ref('')
const search = ref('')
const status = ref('')
const tripType = ref('')
const month = ref('')
const year = ref('')
const page = ref(1)
const tripTypeCounts = ref({ all: 0, inclusive: 0, exclusive: 0 })
const tripTypeCountsSequence = ref(0)

const statusOptions = ['scheduled', 'in_progress', 'completed'].map((value) => ({
  value,
  label: STATUS_LABELS[value],
}))

const tripTypeOptions = computed(() => [
  { value: '', label: `All (${tripTypeCounts.value.all})` },
  {
    value: 'inclusive',
    label: `${TRIP_TYPE_DESCRIPTIONS.inclusive} (${tripTypeCounts.value.inclusive})`,
    dot: 'bg-primary',
  },
  {
    value: 'exclusive',
    label: `${TRIP_TYPE_DESCRIPTIONS.exclusive} (${tripTypeCounts.value.exclusive})`,
    dot: 'bg-secondary',
  },
])

const sortedTrips = computed(() =>
  [...trips.value].sort((a, b) => {
    const dateCompare = getTripStartDate(a).localeCompare(getTripStartDate(b))
    if (dateCompare !== 0) return dateCompare
    return String(a.departure_time ?? '').localeCompare(String(b.departure_time ?? ''))
  }),
)

const filteredTrips = computed(() => sortedTrips.value)
const pageTrips = computed(() => sortedTrips.value)

watch(search, (_, __, onCleanup) => {
  page.value = 1
  const timeout = setTimeout(() => {
    fetchTrips()
    fetchTripTypeCounts()
  }, 250)
  onCleanup(() => clearTimeout(timeout))
})

watch([status, month, year], () => {
  page.value = 1
  fetchTrips()
  fetchTripTypeCounts()
})

watch(tripType, () => {
  page.value = 1
  fetchTrips()
})

async function fetchTrips() {
  loading.value = true
  loadError.value = ''

  try {
    const response = await api.get('/my-trips', {
      params: {
        page: page.value,
        status: status.value || undefined,
        trip_type: tripType.value || undefined,
        month: month.value || undefined,
        year: year.value || undefined,
        search: search.value.trim() || undefined,
      },
    })
    trips.value = response.data?.data ?? []
    paginationMeta.value = response.data?.meta ?? paginationMeta.value
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load your trip schedule.')
  } finally {
    loading.value = false
  }
}

async function fetchTripTypeCounts() {
  const sequence = ++tripTypeCountsSequence.value
  const params = {
    status: status.value || undefined,
    month: month.value || undefined,
    year: year.value || undefined,
    search: search.value.trim() || undefined,
    page: 1,
  }

  try {
    const responses = await Promise.all(
      ['', 'inclusive', 'exclusive'].map((value) =>
        api.get('/my-trips', {
          params: { ...params, trip_type: value || undefined },
        }),
      ),
    )
    if (sequence !== tripTypeCountsSequence.value) return

    const total = (response) => Number(response.data?.meta?.total ?? response.data?.data?.length ?? 0)
    tripTypeCounts.value = {
      all: total(responses[0]),
      inclusive: total(responses[1]),
      exclusive: total(responses[2]),
    }
  } catch (error) {
    if (sequence === tripTypeCountsSequence.value) {
      toast.error(errorMessage(error, 'Unable to load trip type counts.'))
    }
  }
}

onMounted(() => {
  fetchTrips()
  fetchTripTypeCounts()
})

function changePage(value) {
  page.value = value
  fetchTrips()
}
</script>

<template>
  <div class="flex flex-col gap-page">
    <div class="page-header">
      <div class="page-header-copy">
        <h1 class="text-page-title">My Trip Schedule</h1>
        <p class="mt-1 text-small text-ink-muted">
          View the trips associated with your vehicle requests.
        </p>
      </div>
      <div class="page-actions">
        <RefreshButton :loading="loading" label="Refresh my trips" @click="fetchTrips" />
      </div>
    </div>

    <div>
      <p class="text-small text-ink-muted">
        {{ paginationMeta.total }} scheduled {{ paginationMeta.total === 1 ? 'trip' : 'trips' }}
      </p>
    </div>

    <BaseCard>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <BaseInput
          v-model="search"
          class="sm:col-span-2 lg:col-span-4"
          type="search"
          placeholder="Search trips..."
        />
        <SegmentedControl
          class="sm:col-span-2 lg:col-span-4"
          :model-value="tripType"
          :options="tripTypeOptions"
          label="Trip type"
          @update:model-value="tripType = $event"
        />
        <div class="grid grid-cols-1 gap-3 sm:col-span-2 sm:grid-cols-3 lg:col-span-4">
          <BaseSelect v-model="status" :options="statusOptions" placeholder="All statuses" allow-empty />
          <BaseSelect v-model="month" :options="MONTH_OPTIONS" placeholder="All months" allow-empty />
          <BaseSelect v-model="year" :options="YEAR_OPTIONS" placeholder="All years" allow-empty />
        </div>
      </div>
    </BaseCard>

    <BaseCard>
      <div v-if="loading" class="flex justify-center p-12" aria-label="Loading your trips">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <LoadError v-else-if="loadError" :message="loadError" @retry="fetchTrips" />

      <EmptyState
        v-else-if="!loadError && !paginationMeta.total"
        title="No scheduled trips yet"
        message="Trips connected to your vehicle requests will appear here once scheduled."
      />

      <ul v-else-if="!loadError" class="flex flex-col divide-y divide-line">
        <li
          v-for="trip in pageTrips"
          :key="trip.id"
          class="flex flex-col gap-3 py-4 first:pt-0 last:pb-0"
        >
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div>
              <h2 class="text-body font-semibold text-ink">
                {{ trip.destination || 'Destination not specified' }}
              </h2>
              <p class="mt-1 text-small text-ink-muted">
                {{ formatDate(getTripStartDate(trip)) }}
              </p>
            </div>
            <StatusBadge :status="trip.trip_status || 'scheduled'" />
          </div>

          <p v-if="trip.purpose" class="text-small text-ink-muted">
            {{ trip.purpose }}
          </p>

          <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div class="rounded-card bg-surface p-3">
              <p class="text-xs text-ink-muted">Departure</p>
              <p class="mt-1 text-small font-medium text-ink">
                {{ formatTime(trip.departure_time) }}
              </p>
              <p class="mt-2 text-xs text-ink-muted">Estimated return</p>
              <p class="mt-1 text-small font-medium text-ink">
                {{ formatTime(trip.estimated_return_time) }}
              </p>
            </div>

            <div class="rounded-card bg-surface p-3">
              <p class="text-xs text-ink-muted">Assigned vehicle</p>
              <p class="mt-1 text-small font-medium text-ink">
                {{ trip.vehicle ? vehicleName(trip) : 'Not assigned' }}
              </p>
              <p class="mt-2 text-xs text-ink-muted">Driver</p>
              <p class="mt-1 text-small font-medium text-ink">
                {{ trip.driver ? driverName(trip) : 'Not assigned' }}
              </p>
              <p v-if="trip.driver && driverContact(trip) !== '—'" class="mt-1 text-xs text-ink-muted">
                Contact: {{ driverContact(trip) }}
              </p>
            </div>
          </div>
        </li>
      </ul>
      <PaginationBar v-if="!loading" :meta="paginationMeta" @change="changePage" />
    </BaseCard>
  </div>
</template>