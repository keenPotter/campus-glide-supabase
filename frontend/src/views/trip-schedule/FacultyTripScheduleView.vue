<script setup>
import { computed, onMounted, ref } from 'vue'
import api, { errorMessage, unwrap } from '@/lib/api'
import { formatDate, formatTime } from '@/lib/format'
import { driverContact, driverName, getTripStartDate, vehicleName } from '@/lib/trips'
import BaseCard from '@/components/ui/BaseCard.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const trips = ref([])
const loading = ref(true)
const loadError = ref('')

const sortedTrips = computed(() =>
  [...trips.value].sort((a, b) => {
    const dateCompare = getTripStartDate(a).localeCompare(getTripStartDate(b))
    if (dateCompare !== 0) return dateCompare
    return String(a.departure_time ?? '').localeCompare(String(b.departure_time ?? ''))
  }),
)

async function fetchTrips() {
  loading.value = true
  loadError.value = ''

  try {
    const payload = unwrap(await api.get('/my-trips'))
    trips.value = Array.isArray(payload) ? payload : []
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load your trip schedule.')
  } finally {
    loading.value = false
  }
}

onMounted(fetchTrips)
</script>

<template>
  <div class="flex flex-col gap-page">
    <div>
      <h1 class="text-page-title">My Trip Schedule</h1>
      <p class="mt-1 text-small text-ink-muted">
        View the trips associated with your vehicle requests.
      </p>
    </div>

    <div class="flex items-center justify-between gap-3">
      <p class="text-small text-ink-muted">
        {{ sortedTrips.length }} scheduled {{ sortedTrips.length === 1 ? 'trip' : 'trips' }}
      </p>
      <BaseButton variant="outline" size="sm" :disabled="loading" @click="fetchTrips">
        Refresh
      </BaseButton>
    </div>

    <BaseCard>
      <div v-if="loading" class="py-8 text-center text-small text-ink-muted">
        Loading your trips...
      </div>

      <div v-else-if="loadError" class="flex flex-col items-start gap-3 py-4">
        <p class="text-body text-red-700">{{ loadError }}</p>
        <BaseButton @click="fetchTrips">Try again</BaseButton>
      </div>

      <EmptyState
        v-else-if="!sortedTrips.length"
        title="No scheduled trips yet"
        message="Trips connected to your vehicle requests will appear here once scheduled."
      />

      <ul v-else class="flex flex-col divide-y divide-line">
        <li
          v-for="trip in sortedTrips"
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
    </BaseCard>
  </div>
</template>