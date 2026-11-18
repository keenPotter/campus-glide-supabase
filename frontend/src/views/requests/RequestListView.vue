<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { Check, Eye, Pencil, X } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import api, { errorMessage, unwrap } from '@/lib/api'
import {
  formatDate,
  formatDateTime,
  formatTime,
  fullName,
  MONTH_OPTIONS,
  STATUS_LABELS,
  TRIP_TYPE_DESCRIPTIONS,
  YEAR_OPTIONS,
} from '@/lib/format'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import RefreshButton from '@/components/ui/RefreshButton.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import ApproveAssignModal from '@/components/requests/ApproveAssignModal.vue'
import DisapproveRequestModal from '@/components/requests/DisapproveRequestModal.vue'
import VehicleRequestModal from '@/components/requests/VehicleRequestModal.vue'
import VehicleRequestEditModal from '@/components/requests/VehicleRequestEditModal.vue'
import OnSiteBookingModal from '@/components/requests/OnSiteBookingModal.vue'

const auth = useAuthStore()
const store = useVehicleRequestStore()
const router = useRouter()
const route = useRoute()
const toast = useToast()
const search = ref('')
const selectedRequest = ref(null)
const detailRequest = ref(null)
const detailLoading = ref(false)
const showNewRequest = ref(false)
const showOnSiteBooking = ref(false)
const editingRequest = ref(null)
const tripTypeCounts = ref({ all: 0, inclusive: 0, exclusive: 0 })
const tripTypeCountsSequence = ref(0)

watch(
  () => route.query.create,
  (value) => {
    if (value === '1') showNewRequest.value = true
  },
  { immediate: true },
)

// Same style of filter as the Maintenance page: dropdowns with an "All" choice.
const statusOptions = ['pending', 'approved', 'disapproved'].map((value) => ({
  value,
  label: STATUS_LABELS[value],
}))

const tripTypeFilterOptions = computed(() => [
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

const disapproving = ref(null)
// The pending request that is being approved. The assign window is open while this is set.
const approving = ref(null)
function canEditRequest(request) {
  return auth.isFaculty && ['pending', 'approved'].includes(request?.status)
}
const canEditSelectedRequest = computed(() => canEditRequest(detailRequest.value))
const requestDetailRows = computed(() => {
  const request = detailRequest.value
  if (!request) return []

  return [
    { label: 'Booking source', value: request.booking_source === 'on_site' ? 'On-Site' : 'Online' },
    {
      label: request.booking_source === 'on_site' ? 'Requesting personnel' : 'Requesting official',
      value: requesterName(request),
    },
    ...(request.booking_source === 'on_site'
      ? [
          { label: 'Department', value: request.requester_department },
          { label: 'Contact number', value: request.requester_contact },
        ]
      : []),
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

function requesterName(request) {
  return request.requester_name || fullName(request.requested_by) || '—'
}

// Reset the filters too, because the store is shared with other pages.
onMounted(() => {
  store.fetch({ status: '', trip_type: '', month: '', year: '', search: '', page: 1 })
  loadTripTypeCounts()
})

watch(search, (_, __, onCleanup) => {
  const timeout = setTimeout(() => {
    store.fetch({ search: search.value, page: 1 })
    loadTripTypeCounts()
  }, 250)
  onCleanup(() => clearTimeout(timeout))
})

async function loadTripTypeCounts() {
  const sequence = ++tripTypeCountsSequence.value
  const params = {
    status: store.filters.status || undefined,
    month: store.filters.month || undefined,
    year: store.filters.year || undefined,
    search: (store.filters.search || search.value).trim() || undefined,
    page: 1,
    per_page: 1,
  }

  try {
    const responses = await Promise.all(
      ['', 'inclusive', 'exclusive'].map((tripType) =>
        api.get('/vehicle-requests', {
          params: { ...params, trip_type: tripType || undefined },
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

function changeStatus(value) {
  store.fetch({ status: value, search: search.value, page: 1 })
  loadTripTypeCounts()
}

function changeType(value) {
  store.fetch({ trip_type: value, search: search.value, page: 1 })
}

function changeMonth(value) {
  store.fetch({ month: value, search: search.value, page: 1 })
  loadTripTypeCounts()
}

function changeYear(value) {
  store.fetch({ year: value, search: search.value, page: 1 })
  loadTripTypeCounts()
}

function openRequest(request) {
  selectedRequest.value = request
  detailRequest.value = request
  detailLoading.value = true

  api.get(`/vehicle-requests/${request.id}`)
    .then((response) => {
      if (selectedRequest.value?.id === request.id) detailRequest.value = unwrap(response)
    })
    .catch((error) => toast.error(errorMessage(error, 'Unable to load this request.')))
    .finally(() => {
      if (selectedRequest.value?.id === request.id) detailLoading.value = false
    })
}

function closeRequest() {
  selectedRequest.value = null
  detailRequest.value = null
  detailLoading.value = false
}

function closeNewRequest() {
  showNewRequest.value = false
  if (route.query.create === '1') router.replace({ name: 'requests.index' })
}

async function onRequestSubmitted() {
  closeNewRequest()
  try {
    await store.fetch({ page: 1 })
  } catch (error) {
    toast.error(errorMessage(error, 'Request submitted, but the list could not be refreshed.'))
  }
}

async function onOnSiteBookingSubmitted(request) {
  showOnSiteBooking.value = false
  toast.success(
    request.status === 'approved'
      ? 'On-site trip recorded and scheduled.'
      : 'On-site request recorded and added to the allocation queue.',
  )
  try {
    await store.fetch({ page: 1 })
  } catch (error) {
    toast.error(errorMessage(error, 'Request recorded, but the list could not be refreshed.'))
  }
}

function editSelectedRequest() {
  openEditRequest(detailRequest.value)
}

function openEditRequest(request) {
  if (!canEditRequest(request)) return
  closeRequest()
  editingRequest.value = request
}

async function onRequestUpdated() {
  editingRequest.value = null
  try {
    await store.fetch()
  } catch (error) {
    toast.error(errorMessage(error, 'Request updated, but the list could not be refreshed.'))
  }
}

// Clicking anywhere on a row or card opens the request.
// Clicks on a button or link are skipped, so they keep doing their own job.
function onRowClick(event, request) {
  if (event.target.closest('a, button')) return
  openRequest(request)
}

// Approve opens the assign window. The request is approved only after the vehicle and driver are saved.
function openApprove(request) {
  closeRequest()
  approving.value = request
}

function onApproved() {
  const request = approving.value
  approving.value = null
  toast.success(`Request #${request.id} approved. Vehicle and driver assigned.`)
  store.fetch()
}

function openDisapprove(request) {
  closeRequest()
  disapproving.value = request
}

function onDisapproved() {
  disapproving.value = null
  store.fetch()
}
</script>

<template>
  <div class="flex flex-col gap-page">
    <!-- Page Header -->
    <div class="page-header">
      <div class="page-header-copy">
        <h1 class="text-page-title">
          {{ auth.isFaculty ? 'My vehicle requests' : 'Vehicle requests' }}
        </h1>
        <p class="mt-1 text-small text-ink-muted">Request for Use of Vehicle (NVSU-FR-PPS-13-02)</p>
      </div>

      <div class="page-actions">
        <RefreshButton :loading="store.loading" label="Refresh vehicle requests" @click="store.fetch()" />
        <BaseButton v-if="auth.isAdministrator" size="sm" @click="showOnSiteBooking = true">
          + Direct Trip Booking
        </BaseButton>
        <BaseButton v-if="auth.isFaculty" size="sm" @click="showNewRequest = true">
          New request
        </BaseButton>
      </div>
    </div>

    <!-- Filters -->
    <BaseCard>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <BaseInput
          v-model="search"
          class="sm:col-span-2 lg:col-span-4"
          type="search"
          placeholder="Search requests..."
        />
        <SegmentedControl
          class="sm:col-span-2 lg:col-span-4"
          :model-value="store.filters.trip_type"
          :options="tripTypeFilterOptions"
          label="Trip type"
          @update:model-value="changeType"
        />
        <div class="grid grid-cols-1 gap-3 sm:col-span-2 sm:grid-cols-3 lg:col-span-4">
          <BaseSelect
            :model-value="store.filters.status"
            :options="statusOptions"
            placeholder="All status"
            allow-empty
            @update:model-value="changeStatus"
          />
          <BaseSelect
            :model-value="store.filters.month"
            :options="MONTH_OPTIONS"
            placeholder="All months"
            allow-empty
            @update:model-value="changeMonth"
          />
          <BaseSelect
            :model-value="store.filters.year"
            :options="YEAR_OPTIONS"
            placeholder="All years"
            allow-empty
            @update:model-value="changeYear"
          />
        </div>
      </div>
    </BaseCard>

    <!-- Content Area -->
    <div v-if="store.loading" class="flex justify-center p-12">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
    </div>

    <EmptyState
      v-else-if="!store.items.length"
      title="No requests found"
      message="Try a different filter, or create a new request."
    />

    <!-- Card view keeps request details and actions readable until a wide table fits. -->
    <div v-else class="grid grid-cols-1 gap-3 md:grid-cols-2 md:gap-4 2xl:hidden">
      <div
        v-for="request in store.items"
        :key="request.id"
        class="card-row !mb-0 flex cursor-pointer flex-col transition active:bg-neutral-50"
        @click="onRowClick($event, request)"
      >
        <div class="card-row-header w-full flex-col md:flex-row">
          <div class="min-w-0 w-full flex-1 md:w-auto">
            <button
              type="button"
              class="card-row-value block w-full truncate text-left"
              :title="request.destination"
              @click="openRequest(request)"
            >
              {{ request.destination }}
            </button>
            <p class="mt-0.5 truncate text-small text-ink-muted">{{ request.purpose }}</p>
          </div>
          <div class="flex shrink-0 flex-wrap items-center gap-2 self-start">
            <span
              class="rounded-full px-2 py-1 text-xs font-medium"
              :class="request.booking_source === 'on_site' ? 'bg-secondary-50 text-secondary-700' : 'bg-neutral-100 text-ink-muted'"
            >
              {{ request.booking_source === 'on_site' ? 'On-Site' : 'Online' }}
            </span>
            <StatusBadge :status="request.status" />
          </div>
        </div>

        <div class="mb-3 space-y-1.5 md:space-y-2">
          <div class="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
            <span class="card-row-label shrink-0 md:text-body">Requested by</span>
            <span class="min-w-0 flex-1 break-words text-right text-small text-ink md:text-body">{{ requesterName(request) }}</span>
          </div>
          <div class="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
            <span class="card-row-label shrink-0">Travel date</span>
            <span class="min-w-0 flex-1 text-right text-small text-ink">{{ formatDate(request.trip_date) }}</span>
          </div>
          <div class="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
            <span class="card-row-label shrink-0">Departure</span>
            <span class="min-w-0 flex-1 text-right text-small text-ink">{{ formatTime(request.departure_time) }}</span>
          </div>
          <div class="flex flex-wrap items-start justify-between gap-x-3 gap-y-1">
            <span class="card-row-label shrink-0">Passengers</span>
            <span class="min-w-0 flex-1 text-right text-small text-ink">{{ request.number_of_passengers ?? '—' }}</span>
          </div>
          <div
            v-if="request.status === 'disapproved' && request.disapproval_reason"
            class="flex items-start justify-between gap-3"
          >
            <span class="card-row-label shrink-0">Reason</span>
            <span class="min-w-0 flex-1 break-words text-right text-small text-red-700">
              {{ request.disapproval_reason }}
            </span>
          </div>
        </div>

        <div class="mt-auto flex flex-wrap items-center justify-end gap-2 border-t border-line pt-3">
          <BaseButton
            size="sm"
            variant="ghost"
            @click="openRequest(request)"
          >
            <Eye :size="16" aria-hidden="true" /> View
          </BaseButton>
          <BaseButton
            v-if="canEditRequest(request)"
            size="sm"
            variant="outline"
            @click="openEditRequest(request)"
          >
            <Pencil :size="16" aria-hidden="true" /> Edit
          </BaseButton>

          <template v-if="auth.isAdministrator && request.status === 'pending'">
            <BaseButton size="sm" @click="openApprove(request)">
              <Check :size="16" aria-hidden="true" /> Approve
            </BaseButton>
            <BaseButton size="sm" variant="outline" @click="openDisapprove(request)">
              <X :size="16" aria-hidden="true" /> Disapprove
            </BaseButton>
          </template>
        </div>
      </div>
    </div>

    <!-- Wide-screen table view. -->
    <div
      v-if="!store.loading && store.items.length"
      class="hidden overflow-hidden rounded-card border border-line bg-white shadow-card 2xl:block"
    >
      <table class="w-full table-fixed border-collapse">
        <thead class="table-head">
          <tr>
            <th scope="col" class="w-[16%] px-2 py-3 xl:px-card">Destination</th>
            <th scope="col" class="w-[12%] px-2 py-3 xl:px-card">Requested by</th>
            <th scope="col" class="w-[13%] px-2 py-3 xl:px-card">Travel</th>
            <th scope="col" class="w-[5%] px-2 py-3 xl:px-card">Pax</th>
            <th scope="col" class="w-[12%] px-2 py-3 xl:px-card">Status</th>
            <th scope="col" class="w-[17%] px-2 py-3 xl:px-card">Reason</th>
            <th scope="col" class="w-[25%] px-2 py-3 text-right xl:px-card">Actions</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-line text-body">
          <tr
            v-for="request in store.items"
            :key="request.id"
            class="table-row-interactive"
            tabindex="0"
            @click="onRowClick($event, request)"
            @keydown.enter="onRowClick($event, request)"
          >
            <td class="px-2 py-3 align-top xl:px-card">
              <button
                type="button"
                class="break-words text-left font-medium"
                @click="openRequest(request)"
              >
                {{ request.destination }}
              </button>
              <p class="truncate text-small text-ink-muted">{{ request.purpose }}</p>
            </td>
            <td class="px-2 py-3 align-top text-small xl:px-card">
              <span class="break-words">{{ requesterName(request) }}</span>
            </td>
            <td class="px-2 py-3 align-top text-small xl:px-card">
              <p>
                {{ formatDate(request.trip_date) }}
                <span v-if="request.travel_days > 1" class="text-ink-muted">
                  ({{ request.travel_days }} days)
                </span>
              </p>
              <p class="text-ink-muted">{{ formatTime(request.departure_time) }}</p>
            </td>
            <td class="px-2 py-3 align-top text-small xl:px-card">{{ request.number_of_passengers ?? '—' }}</td>
            <td class="px-2 py-3 align-top xl:px-card">
              <div class="flex flex-col items-start gap-1">
                <span
                  class="rounded-full px-2 py-1 text-xs font-medium"
                  :class="request.booking_source === 'on_site' ? 'bg-secondary-50 text-secondary-700' : 'bg-neutral-100 text-ink-muted'"
                >
                  {{ request.booking_source === 'on_site' ? 'On-Site' : 'Online' }}
                </span>
                <StatusBadge :status="request.status" />
              </div>
            </td>
            <!-- Reason for disapproval. Blank when there is none. -->
            <td class="px-2 py-3 align-top text-small text-ink-muted xl:px-card">
              <p
                v-if="request.disapproval_reason"
                class="line-clamp-3 break-words text-red-700"
                :title="request.disapproval_reason"
              >
                {{ request.disapproval_reason }}
              </p>
            </td>
            <td class="px-2 py-3 align-top xl:px-card">
              <div class="flex flex-nowrap items-center justify-end gap-1.5">
                <template v-if="auth.isAdministrator && request.status === 'pending'">
                  <BaseButton size="sm" @click="openApprove(request)">
                    <Check :size="16" aria-hidden="true" /> Approve
                  </BaseButton>
                  <BaseButton size="sm" variant="outline" @click="openDisapprove(request)">
                    <X :size="16" aria-hidden="true" /> Disapprove
                  </BaseButton>
                </template>

                <BaseButton size="sm" variant="ghost" @click="openRequest(request)">
                  <Eye :size="16" aria-hidden="true" /> View
                </BaseButton>
                <BaseButton
                  v-if="canEditRequest(request)"
                  size="sm"
                  variant="outline"
                  @click="openEditRequest(request)"
                >
                  <Pencil :size="16" aria-hidden="true" /> Edit
                </BaseButton>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <PaginationBar :meta="store.meta" @change="(page) => store.fetch({ page })" />
    </div>

    <!-- Pagination for the card view. -->
    <div
      v-if="!store.loading && store.items.length"
      class="overflow-hidden rounded-card border border-line bg-white 2xl:hidden"
    >
      <PaginationBar :meta="store.meta" @change="(page) => store.fetch({ page })" />
    </div>

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
        <BaseButton v-if="canEditSelectedRequest" variant="outline" @click="editSelectedRequest">
          Edit
        </BaseButton>
        <template v-if="auth.isAdministrator && detailRequest?.status === 'pending'">
          <BaseButton @click="openApprove(detailRequest)">Approve</BaseButton>
          <BaseButton variant="outline" @click="openDisapprove(detailRequest)">
            Disapprove
          </BaseButton>
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
      @close="closeNewRequest"
      @submitted="onRequestSubmitted"
    />
    <VehicleRequestEditModal
      :request="editingRequest"
      @close="editingRequest = null"
      @saved="onRequestUpdated"
    />
    <OnSiteBookingModal
      :open="showOnSiteBooking"
      @close="showOnSiteBooking = false"
      @submitted="onOnSiteBookingSubmitted"
    />
  </div>
</template>