<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import api, { errorMessage, unwrap } from '@/lib/api'
import { formatDate, formatDateTime, formatTime, fullName, ROLE_LABELS } from '@/lib/format'
import { useToast } from '@/composables/useToast'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import RefreshButton from '@/components/ui/RefreshButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import LoadError from '@/components/ui/LoadError.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import ApproveAssignModal from '@/components/requests/ApproveAssignModal.vue'
import DisapproveRequestModal from '@/components/requests/DisapproveRequestModal.vue'
import VehicleRequestModal from '@/components/requests/VehicleRequestModal.vue'
import VehicleRequestEditModal from '@/components/requests/VehicleRequestEditModal.vue'

const auth = useAuthStore()
const requests = useVehicleRequestStore()
const toast = useToast()

const PAGE_SIZE = 5

const loading = ref(true)
const loadError = ref('')
const summary = ref({ counts: {}, upcoming: [] })
const page = ref(1)
const search = ref('')
const selectedRequest = ref(null)
const detailRequest = ref(null)
const detailLoading = ref(false)
const approving = ref(null)
const disapproving = ref(null)
const showNewRequest = ref(false)
const editingRequest = ref(null)

const requestDetailRows = computed(() => {
  const request = detailRequest.value
  if (!request) return []

  return [
    { label: 'Requesting official', value: fullName(request.requested_by) },
    { label: 'Destination', value: request.destination },
    { label: 'Purpose', value: request.purpose },
    { label: 'Date of travel', value: formatDate(request.trip_date) },
    { label: 'End of travel', value: formatDate(request.trip_end_date) },
    { label: 'Days of travel', value: request.travel_days ?? '—' },
    { label: 'Trip type', value: request.trip_type },
    { label: 'Time of departure', value: formatTime(request.departure_time) },
    { label: 'Estimated return', value: formatTime(request.return_time) },
    { label: 'Authorized passengers', value: request.passengers },
    { label: 'Number of passengers', value: request.number_of_passengers ?? '—' },
    { label: 'Date requested', value: formatDateTime(request.created_at) },
    { label: 'Approved on', value: request.approved_date ? formatDateTime(request.approved_date) : '—' },
  ]
})

// The numbers come from the server totals, so they cover every page of requests.
async function load(searchQuery = search.value) {
  loading.value = true
  loadError.value = ''

  try {
    summary.value = await requests.fetchSummary(searchQuery, auth.isStaff)
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
    { label: 'Pending Requests', value: counts.pending ?? 0, tone: 'secondary' },
    { label: 'Approved Requests', value: counts.approved ?? 0, tone: 'primary' },
    { label: 'Disapproved Requests', value: counts.disapproved ?? 0, tone: 'danger' },
  ]
})

const tones = {
  primary: 'bg-primary-50 text-primary-700',
  secondary: 'bg-secondary-50 text-secondary-700',
  danger: 'bg-red-50 text-red-700',
}

const upcoming = computed(() => summary.value.upcoming ?? [])
const filteredUpcoming = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return upcoming.value

  return upcoming.value.filter((request) =>
    [request.destination, request.purpose, fullName(request.requested_by), request.status]
      .join(' ')
      .toLowerCase()
      .includes(query),
  )
})

/* ================= PAGINATION ================= */

const pageCount = computed(() => Math.max(1, Math.ceil(filteredUpcoming.value.length / PAGE_SIZE)))

const pagedUpcoming = computed(() =>
  filteredUpcoming.value.slice((page.value - 1) * PAGE_SIZE, page.value * PAGE_SIZE),
)

const paginationMeta = computed(() => ({
  current_page: page.value,
  last_page: pageCount.value,
  total: filteredUpcoming.value.length,
}))

watch(search, (_, __, onCleanup) => {
  page.value = 1
  const timeout = setTimeout(() => load(), 250)
  onCleanup(() => clearTimeout(timeout))
})

async function openRequest(request) {
  selectedRequest.value = request
  detailRequest.value = request
  detailLoading.value = true

  try {
    const response = await api.get(`/vehicle-requests/${request.id}`)
    if (selectedRequest.value?.id === request.id) detailRequest.value = unwrap(response)
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to load this request.'))
  } finally {
    if (selectedRequest.value?.id === request.id) detailLoading.value = false
  }
}

function closeRequest() {
  selectedRequest.value = null
  detailRequest.value = null
  detailLoading.value = false
}

function openApprove(request) {
  closeRequest()
  approving.value = request
}

function openDisapprove(request) {
  closeRequest()
  disapproving.value = request
}

async function onApproved() {
  const request = approving.value
  approving.value = null
  await load()
  toast.success(`Request #${request.id} approved. Vehicle and driver assigned.`)
}

async function onDisapproved() {
  disapproving.value = null
  await load()
  toast.success('Request disapproved.')
}

function editSelectedRequest() {
  const request = detailRequest.value
  closeRequest()
  if (request) editingRequest.value = request
}

async function onRequestUpdated() {
  editingRequest.value = null
  await load()
}

async function onRequestSubmitted() {
  showNewRequest.value = false
  await load()
}

// If the list gets shorter (for example after a reload), stay on a page that exists.
watch(pageCount, (count) => {
  if (page.value > count) page.value = count
})
</script>

<template>
  <div class="flex flex-col gap-page">
    <!-- Greeting -->
    <div class="page-header">
      <div class="page-header-copy">
        <h1 class="text-page-title">Hello, {{ auth.user?.first_name }}</h1>
        <p class="mt-1 text-small text-ink-muted">
          Signed in as {{ ROLE_LABELS[auth.role] ?? auth.role }}
        </p>
      </div>
      <div class="page-actions">
        <RefreshButton :loading="loading" label="Refresh dashboard" @click="load" />
        <BaseButton v-if="auth.isFaculty" size="sm" @click="showNewRequest = true">
          New request
        </BaseButton>
      </div>
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
    <BaseCard title="Upcoming vehicle requests" subtitle="Vehicle requests ordered by requested trip date. Approval does not mean a trip has been scheduled." :padded="false">
      <template #actions>
        <RouterLink
          v-if="!auth.isStaff"
          :to="{ name: 'requests.index' }"
          class="text-small font-medium text-primary hover:underline"
        >
          View all
        </RouterLink>
      </template>

      <div class="px-card pt-card pb-4">
        <BaseInput v-model="search" type="search" placeholder="Search requests..." />
      </div>

      <div v-if="loading" class="flex justify-center p-12">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <EmptyState
        v-else-if="!filteredUpcoming.length"
        title="No upcoming vehicle requests"
        :message="search ? 'No upcoming requests match your search.' : 'Vehicle requests you create or approve will appear here. These are requests, not confirmed scheduled trips.'"
      />

      <ul v-else class="flex flex-col divide-y divide-line">
        <li v-for="request in pagedUpcoming" :key="request.id">
          <button
            type="button"
            class="flex w-full flex-col gap-2 px-card py-3 text-left transition-colors hover:bg-neutral-50 hover:filter-none"
            @click="openRequest(request)"
          >
            <div class="flex w-full flex-wrap items-start justify-between gap-2">
              <span class="min-w-0 flex-1 break-words text-body font-medium text-ink">{{ request.destination }}</span>
              <StatusBadge :status="request.status" class="shrink-0" />
            </div>
            <span class="text-small text-ink-muted">
              {{ formatDate(request.trip_date) }} · {{ formatTime(request.departure_time) }}
            </span>
            <span class="text-small text-ink-muted">{{ fullName(request.requested_by) }}</span>
          </button>
        </li>
      </ul>

      <PaginationBar
        v-if="!loading && filteredUpcoming.length > PAGE_SIZE"
        :meta="paginationMeta"
        @change="(value) => (page = value)"
      />
    </BaseCard>

    <BaseModal
      :open="Boolean(selectedRequest)"
      :title="selectedRequest ? `Vehicle request #${selectedRequest.id}` : 'Vehicle request'"
      :subtitle="detailRequest?.destination ?? selectedRequest?.destination ?? ''"
      @close="closeRequest"
    >
      <div v-if="detailLoading" class="flex justify-center p-8" aria-label="Loading request details">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <template v-else-if="detailRequest">
        <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
          <StatusBadge :status="detailRequest.status" />
        </div>
        <div
          v-if="detailRequest.disapproval_reason"
          class="mb-3 rounded-card border border-red-200 bg-red-50 p-3 text-small text-red-800"
        >
          <p class="font-medium">Disapproved</p>
          <p class="mt-1">{{ detailRequest.disapproval_reason }}</p>
        </div>
        <div
          v-if="detailRequest.edit_reason && detailRequest.status === 'pending'"
          class="mb-3 rounded-card border-l-4 border-secondary bg-secondary-50 p-3 text-small text-secondary-700"
        >
          <p class="font-medium">Edited after approval</p>
          <p class="mt-1">Reason: {{ detailRequest.edit_reason }}</p>
        </div>
        <dl class="divide-y divide-line">
          <div
            v-for="row in requestDetailRows"
            :key="row.label"
            class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4"
          >
            <dt class="text-small text-ink-muted">{{ row.label }}</dt>
            <dd class="text-body sm:col-span-2 sm:capitalize">{{ row.value || '—' }}</dd>
          </div>
        </dl>
      </template>

      <template #footer>
        <BaseButton variant="outline" @click="closeRequest">Close</BaseButton>
        <BaseButton
          v-if="auth.isFaculty && ['pending', 'approved'].includes(detailRequest?.status)"
          variant="outline"
          @click="editSelectedRequest"
        >
          Edit
        </BaseButton>
        <template v-if="auth.isAdministrator && detailRequest?.status === 'pending'">
          <BaseButton @click="openApprove(detailRequest)">Approve</BaseButton>
          <BaseButton variant="outline" @click="openDisapprove(detailRequest)">Disapprove</BaseButton>
        </template>
      </template>
    </BaseModal>

    <ApproveAssignModal :request="approving" @close="approving = null" @done="onApproved" />
    <DisapproveRequestModal
      :request="disapproving"
      @close="disapproving = null"
      @done="onDisapproved"
    />
    <VehicleRequestModal
      :open="showNewRequest"
      @close="showNewRequest = false"
      @submitted="onRequestSubmitted"
    />
    <VehicleRequestEditModal
      :request="editingRequest"
      @close="editingRequest = null"
      @saved="onRequestUpdated"
    />
  </div>
</template>