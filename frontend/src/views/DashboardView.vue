<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import { errorMessage } from '@/lib/api'
import { formatDate, formatTime, fullName, ROLE_LABELS } from '@/lib/format'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import LoadError from '@/components/ui/LoadError.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'

const auth = useAuthStore()
const router = useRouter()
const requests = useVehicleRequestStore()

const PAGE_SIZE = 5

const loading = ref(true)
const loadError = ref('')
const summary = ref({ counts: {}, upcoming: [] })
const page = ref(1)

// The numbers come from the server totals, so they cover every page of requests.
async function load() {
  loading.value = true
  loadError.value = ''

  try {
    summary.value = await requests.fetchSummary()
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load the dashboard.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

const stats = computed(() => {
  const counts = summary.value.counts
  return [
    { label: 'Pending', value: counts.pending ?? 0, tone: 'secondary' },
    { label: 'Approved', value: counts.approved ?? 0, tone: 'primary' },
    { label: 'Disapproved', value: counts.disapproved ?? 0, tone: 'danger' },
  ]
})

const tones = {
  primary: 'bg-primary-50 text-primary-700',
  secondary: 'bg-secondary-50 text-secondary-700',
  danger: 'bg-red-50 text-red-700',
}

const upcoming = computed(() => summary.value.upcoming ?? [])

/* ================= PAGINATION ================= */

const pageCount = computed(() => Math.max(1, Math.ceil(upcoming.value.length / PAGE_SIZE)))

const pagedUpcoming = computed(() =>
  upcoming.value.slice((page.value - 1) * PAGE_SIZE, page.value * PAGE_SIZE),
)

const paginationMeta = computed(() => ({
  current_page: page.value,
  last_page: pageCount.value,
  total: upcoming.value.length,
}))

// If the list gets shorter (for example after a reload), stay on a page that exists.
watch(pageCount, (count) => {
  if (page.value > count) page.value = count
})
</script>

<template>
  <div class="flex flex-col gap-page">
    <!-- Greeting -->
    <div>
      <h1 class="text-page-title">Hello, {{ auth.user?.first_name }}</h1>
      <p class="mt-1 text-small text-ink-muted">
        Signed in as {{ ROLE_LABELS[auth.role] ?? auth.role }}
      </p>
    </div>

    <!-- Quick Action Button (Mobile) -->
    <div v-if="auth.isFaculty" class="md:hidden">
      <BaseButton block @click="router.push({ name: 'requests.create' })">
        New request
      </BaseButton>
    </div>

    <LoadError :message="loadError" @retry="load" />

    <!-- Stats Grid -->
    <div class="responsive-grid">
      <div v-for="stat in stats" :key="stat.label" class="stat-card">
        <span
          class="inline-flex rounded-full px-2 py-0.5 text-small font-medium"
          :class="tones[stat.tone]"
        >
          {{ stat.label }}
        </span>
        <p class="mt-2 text-2xl font-bold">{{ stat.value }}</p>
      </div>
    </div>

    <!-- Upcoming Trips Card -->
    <BaseCard title="Upcoming trips" subtitle="Pending and approved requests, soonest first">
      <template #actions>
        <RouterLink
          v-if="!auth.isStaff"
          :to="{ name: 'requests.index' }"
          class="text-small font-medium text-primary hover:underline"
        >
          View all
        </RouterLink>
      </template>

      <div v-if="loading" class="flex justify-center p-8">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <EmptyState
        v-else-if="!upcoming.length"
        title="No upcoming trips"
        message="Requests you create or approve will appear here."
      />

      <ul v-else class="flex flex-col divide-y divide-line">
        <li
          v-for="request in pagedUpcoming"
          :key="request.id"
          class="flex flex-col gap-2 py-3 first:pt-0 last:pb-0"
        >
          <RouterLink
            v-if="!auth.isStaff"
            :to="{ name: 'requests.show', params: { id: request.id } }"
            class="block text-body font-medium text-ink hover:text-primary"
          >
            {{ request.destination }}
          </RouterLink>
          <p v-else class="block text-body font-medium text-ink">{{ request.destination }}</p>
          <div class="flex flex-wrap items-center justify-between gap-2">
            <p class="text-small text-ink-muted">
              {{ formatDate(request.trip_date) }} · {{ formatTime(request.departure_time) }}
            </p>
            <StatusBadge :status="request.status" />
          </div>
          <p class="text-small text-ink-muted">{{ fullName(request.requested_by) }}</p>
        </li>
      </ul>

      <PaginationBar
        v-if="!loading && upcoming.length > PAGE_SIZE"
        :meta="paginationMeta"
        @change="(value) => (page = value)"
      />
    </BaseCard>
  </div>
</template>