<script setup>
import { computed, ref, watch } from 'vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import CalendarHeader from '@/components/trip-schedule/CalendarHeader.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import TripList from '@/components/trip-schedule/TripList.vue'
import { MONTH_OPTIONS, STATUS_LABELS, YEAR_OPTIONS, formatDate, toDateString } from '@/lib/format'
import { getTripEndDate, getTripStartDate, rangesOverlap } from '@/lib/trips'

const props = defineProps({
  trips: { type: Array, required: true },
  tripType: { type: String, required: true },
  isNewTrip: { type: Function, required: true },
})

const emit = defineEmits(['open-trip'])

const PAGE_SIZE = 10
const viewMode = ref('month')
const selectedMonth = ref(String(new Date().getMonth() + 1))
const selectedYear = ref(String(new Date().getFullYear()))
const listMonth = ref('')
const listYear = ref('')
const listStatus = ref('')
const search = ref('')
const page = ref(1)

const viewOptions = [
  { value: 'month', label: 'Month' },
  { value: 'week', label: 'Week' },
  { value: 'year', label: 'Year' },
  { value: 'unviewed', label: 'Unviewed' },
  { value: 'list', label: 'List' },
]

const statusOptions = ['scheduled', 'in_progress'].map((value) => ({
  value,
  label: STATUS_LABELS[value],
}))

function getSunday(date) {
  const start = new Date(date)
  start.setHours(0, 0, 0, 0)
  start.setDate(start.getDate() - start.getDay())
  return start
}

const weekStart = ref(getSunday(new Date()))

const weekEnd = computed(() => {
  const end = new Date(weekStart.value)
  end.setDate(end.getDate() + 6)
  return end
})

const weekLabel = computed(
  () => `${formatDate(toDateString(weekStart.value))} – ${formatDate(toDateString(weekEnd.value))}`,
)

const sectionTitle = computed(
  () => `${props.tripType === 'inclusive' ? 'Inclusive' : 'Exclusive'} scheduled trips`,
)

const subtitle = computed(() => {
  if (viewMode.value === 'month') {
    const month = MONTH_OPTIONS.find((option) => option.value === selectedMonth.value)?.label
    return `${month} ${selectedYear.value}`
  }
  if (viewMode.value === 'week') return weekLabel.value
  if (viewMode.value === 'year') return selectedYear.value
  if (viewMode.value === 'unviewed') return 'Trips not yet viewed in this browser'
  return 'All scheduled trips'
})

const emptyMessage = computed(() => {
  if (viewMode.value === 'unviewed') return 'No unviewed trips in this section.'
  return `No ${props.tripType} scheduled trips match these filters.`
})

function changeWeek(offset) {
  const next = new Date(weekStart.value)
  next.setDate(next.getDate() + offset * 7)
  weekStart.value = next
}

function matchesSearch(trip) {
  const query = search.value.trim().toLowerCase()
  if (!query) return true

  const text = [
    trip.destination,
    trip.purpose,
    trip.vehicle?.plate_number,
    trip.vehicle?.vehicle_model,
    trip.driver?.name,
    trip.vehicle_request?.requester_name,
    trip.vehicle_request?.requester?.first_name,
    trip.vehicle_request?.requester?.last_name,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()

  return text.includes(query)
}

const filteredTrips = computed(() => {
  const monthStart = toDateString(
    new Date(Number(selectedYear.value), Number(selectedMonth.value) - 1, 1),
  )
  const monthEnd = toDateString(
    new Date(Number(selectedYear.value), Number(selectedMonth.value), 0),
  )
  const yearStart = `${selectedYear.value}-01-01`
  const yearEnd = `${selectedYear.value}-12-31`
  const weekStartDate = toDateString(weekStart.value)
  const weekEndDate = toDateString(weekEnd.value)

  return props.trips.filter((trip) => {
    if (viewMode.value === 'month' && !rangesOverlap(
      getTripStartDate(trip),
      getTripEndDate(trip),
      monthStart,
      monthEnd,
    )) {
      return false
    }

    if (viewMode.value === 'week' && !rangesOverlap(
      getTripStartDate(trip),
      getTripEndDate(trip),
      weekStartDate,
      weekEndDate,
    )) {
      return false
    }

    if (viewMode.value === 'year' && !rangesOverlap(
      getTripStartDate(trip),
      getTripEndDate(trip),
      yearStart,
      yearEnd,
    )) {
      return false
    }

    if (viewMode.value === 'unviewed' && !props.isNewTrip(trip)) return false

    if (viewMode.value === 'list') {
      if (listStatus.value && trip.trip_status !== listStatus.value) return false
      if (!matchesSearch(trip)) return false

      if (listMonth.value) {
        const start = toDateString(
          new Date(Number(listYear.value || new Date().getFullYear()), Number(listMonth.value) - 1, 1),
        )
        const end = toDateString(
          new Date(Number(listYear.value || new Date().getFullYear()), Number(listMonth.value), 0),
        )
        if (!rangesOverlap(getTripStartDate(trip), getTripEndDate(trip), start, end)) return false
      }

      if (listYear.value && !rangesOverlap(
        getTripStartDate(trip),
        getTripEndDate(trip),
        `${listYear.value}-01-01`,
        `${listYear.value}-12-31`,
      )) {
        return false
      }
    }

    return true
  })
})

const paginationMeta = computed(() => ({
  current_page: page.value,
  last_page: Math.max(1, Math.ceil(filteredTrips.value.length / PAGE_SIZE)),
  total: filteredTrips.value.length,
}))

const pageTrips = computed(() => {
  const start = (page.value - 1) * PAGE_SIZE
  return filteredTrips.value.slice(start, start + PAGE_SIZE)
})

watch(filteredTrips, () => {
  page.value = 1
})
</script>

<template>
  <TripList
    :title="sectionTitle"
    :subtitle="subtitle"
    :empty-message="emptyMessage"
    :trips="pageTrips"
    :total-count="filteredTrips.length"
    :is-new-trip="isNewTrip"
    @open-trip="emit('open-trip', $event)"
  >
    <template #controls>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <BaseSelect v-model="viewMode" label="Show" :options="viewOptions" />

        <template v-if="viewMode === 'month'">
          <BaseSelect v-model="selectedMonth" label="Month" :options="MONTH_OPTIONS" />
          <BaseSelect v-model="selectedYear" label="Year" :options="YEAR_OPTIONS" />
        </template>

        <template v-else-if="viewMode === 'year'">
          <BaseSelect v-model="selectedYear" label="Year" :options="YEAR_OPTIONS" />
        </template>

        <template v-else-if="viewMode === 'list'">
          <BaseInput v-model="search" type="search" placeholder="Search trips..." />
          <BaseSelect
            v-model="listStatus"
            :options="statusOptions"
            placeholder="All statuses"
            allow-empty
          />
          <BaseSelect
            v-model="listMonth"
            :options="MONTH_OPTIONS"
            placeholder="All months"
            allow-empty
          />
          <BaseSelect
            v-model="listYear"
            :options="YEAR_OPTIONS"
            placeholder="All years"
            allow-empty
          />
        </template>
      </div>

      <CalendarHeader
        v-if="viewMode === 'week'"
        class="mt-3"
        :title="weekLabel"
        :trip-type="tripType"
        prev-label="Previous week"
        next-label="Next week"
        @prev="changeWeek(-1)"
        @next="changeWeek(1)"
      />
    </template>
  </TripList>

  <PaginationBar
    :meta="paginationMeta"
    :show-single-page="paginationMeta.total > 0"
    @change="page = $event"
  />
</template>
