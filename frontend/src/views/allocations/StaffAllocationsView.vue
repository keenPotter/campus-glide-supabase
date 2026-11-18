<script setup>
import { onMounted, ref, watch } from 'vue'
import api, { errorMessage } from '@/lib/api'
import { formatDate, formatTime } from '@/lib/format'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import LoadError from '@/components/ui/LoadError.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import TripTypeBadge from '@/components/ui/TripTypeBadge.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import RefreshButton from '@/components/ui/RefreshButton.vue'

const allocations = ref([])
const search = ref('')
const paginationMeta = ref(null)
const page = ref(1)
const loading = ref(true)
const loadError = ref('')

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    const response = await api.get('/allocations', {
      params: { per_page: 10, page: page.value, search: search.value || undefined },
    })
    allocations.value = response.data?.data ?? []
    paginationMeta.value = response.data?.meta ?? null
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load allocations.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

function changePage(value) {
  page.value = value
  load()
}

watch(search, (_, __, onCleanup) => {
  page.value = 1
  const timeout = setTimeout(load, 250)
  onCleanup(() => clearTimeout(timeout))
})

watch(paginationMeta, (meta) => {
  if (meta && page.value > meta.last_page) {
    page.value = meta.last_page
    load()
  }
})
</script>

<template>
  <div class="flex flex-col gap-page">
    <div class="page-header">
      <div class="page-header-copy">
        <h1 class="text-page-title">Allocations</h1>
        <p class="mt-1 text-small text-ink-muted">View assigned vehicles, drivers, and scheduled trips. Staff accounts cannot change allocations.</p>
      </div>
      <div class="page-actions">
        <RefreshButton :loading="loading" label="Refresh allocations" @click="load" />
      </div>
    </div>

    <LoadError :message="loadError" @retry="load" />

    <BaseCard title="Allocation records" subtitle="Read-only view">
      <BaseInput v-model="search" type="search" placeholder="Search allocations..." />
      <div v-if="loading" class="flex justify-center p-12">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>
      <EmptyState
        v-else-if="!allocations.length"
        title="No allocations found"
        message="Assigned trips will appear here when available."
      />
      <ul v-else class="mt-4 divide-y divide-line">
        <li v-for="item in allocations" :key="item.id" class="flex flex-col gap-3 py-4 sm:flex-row sm:items-start sm:justify-between">
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <p class="font-semibold text-ink">{{ item.trip?.destination || 'Destination not provided' }}</p>
              <StatusBadge :status="item.status || 'scheduled'" />
              <span
                class="rounded-full px-2 py-1 text-xs font-medium"
                :class="item.vehicle_request?.booking_source === 'on_site' ? 'bg-secondary-50 text-secondary-700' : 'bg-neutral-100 text-ink-muted'"
              >
                {{ item.vehicle_request?.booking_source === 'on_site' ? 'On-Site' : 'Online' }}
              </span>
              <TripTypeBadge :type="item.vehicle_request?.trip_type" />
            </div>
            <p class="mt-1 text-small text-ink-muted">
              {{ formatDate(item.trip?.trip_date) }} · {{ formatTime(item.trip?.departure_time) }}
              <span v-if="item.trip?.trip_end_date && item.trip.trip_end_date !== item.trip?.trip_date"> – {{ formatDate(item.trip.trip_end_date) }}</span>
            </p>
            <p class="mt-2 text-small text-ink">Requester: {{ item.vehicle_request?.requester || '—' }}</p>
            <template v-if="item.vehicle_request?.booking_source === 'on_site'">
              <p class="text-small text-ink-muted">Office/Department: {{ item.vehicle_request?.requester_department || '—' }}</p>
              <p class="text-small text-ink-muted">Contact: {{ item.vehicle_request?.requester_contact || '—' }}</p>
            </template>
            <p class="text-small text-ink-muted">Purpose: {{ item.trip?.purpose || '—' }}</p>
          </div>
          <div class="min-w-0 text-small sm:w-64">
            <p class="font-medium text-ink">{{ item.vehicle?.vehicle_model || 'No vehicle' }} · {{ item.vehicle?.plate_number || '—' }}</p>
            <p class="mt-1 text-ink-muted">Driver: {{ item.driver?.name || '—' }}</p>
            <p class="text-ink-muted">Contact: {{ item.driver?.contact_number || '—' }}</p>
          </div>
        </li>
      </ul>
      <PaginationBar v-if="!loading" :meta="paginationMeta" @change="changePage" />
    </BaseCard>
  </div>
</template>
