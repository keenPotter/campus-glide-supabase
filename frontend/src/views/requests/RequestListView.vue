<script setup>
import { onMounted, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import { formatDate, formatTime, fullName, STATUS_LABELS, TRIP_TYPE_LABELS } from '@/lib/format'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import ApproveAssignModal from '@/components/requests/ApproveAssignModal.vue'
import DisapproveRequestModal from '@/components/requests/DisapproveRequestModal.vue'

const auth = useAuthStore()
const store = useVehicleRequestStore()
const router = useRouter()
const toast = useToast()

// Same style of filter as the Maintenance page: dropdowns with an "All" choice.
const statusOptions = ['pending', 'approved', 'disapproved'].map((value) => ({
  value,
  label: STATUS_LABELS[value],
}))

const typeOptions = ['inclusive', 'exclusive'].map((value) => ({
  value,
  label: TRIP_TYPE_LABELS[value],
}))

const disapproving = ref(null)
// The pending request that is being approved. The assign window is open while this is set.
const approving = ref(null)

// Reset the filters too, because the store is shared with other pages.
onMounted(() => store.fetch({ status: '', trip_type: '', page: 1 }))

function changeStatus(value) {
  store.fetch({ status: value, page: 1 })
}

function changeType(value) {
  store.fetch({ trip_type: value, page: 1 })
}

// True when the row already shows a button besides "View"
// (Approve/Disapprove for pending requests, administrators only).
function hasOtherActions(request) {
  return auth.isAdministrator && request.status === 'pending'
}

function openRequest(request) {
  router.push({ name: 'requests.show', params: { id: request.id } })
}

// Clicking anywhere on a row or card opens the request.
// Clicks on a button or link are skipped, so they keep doing their own job.
function onRowClick(event, request) {
  if (event.target.closest('a, button')) return
  openRequest(request)
}

// Approve opens the assign window. The request is approved only after the vehicle and driver are saved.
function openApprove(request) {
  approving.value = request
}

function onApproved() {
  const request = approving.value
  approving.value = null
  toast.success(`Request #${request.id} approved. Vehicle and driver assigned.`)
  store.fetch()
}

function openDisapprove(request) {
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
    <div class="flex flex-col gap-3">
      <div>
        <h1 class="text-page-title">
          {{ auth.isFaculty ? 'My vehicle requests' : 'Vehicle requests' }}
        </h1>
        <p class="mt-1 text-small text-ink-muted">Request for Use of Vehicle (NVSU-FR-PPS-13-02)</p>
      </div>

      <BaseButton v-if="auth.isFaculty" block @click="router.push({ name: 'requests.create' })">
        New request
      </BaseButton>
    </div>

    <!-- Filters -->
    <BaseCard>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <BaseSelect
          :model-value="store.filters.status"
          :options="statusOptions"
          placeholder="All status"
          allow-empty
          @update:model-value="changeStatus"
        />
        <BaseSelect
          :model-value="store.filters.trip_type"
          :options="typeOptions"
          placeholder="All types"
          allow-empty
          @update:model-value="changeType"
        />
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

    <!-- Mobile + Tablet Card View (1 column on mobile, 2 columns on tablet) -->
    <div v-else class="grid grid-cols-1 gap-3 md:grid-cols-2 md:gap-4 lg:hidden">
      <div
        v-for="request in store.items"
        :key="request.id"
        class="card-row !mb-0 flex cursor-pointer flex-col transition active:bg-neutral-50"
        @click="onRowClick($event, request)"
      >
        <div class="card-row-header">
          <div class="min-w-0 flex-1">
            <RouterLink
              :to="{ name: 'requests.show', params: { id: request.id } }"
              class="card-row-value block truncate hover:text-primary md:text-section-title"
              :title="request.destination"
            >
              {{ request.destination }}
            </RouterLink>
            <p class="mt-0.5 truncate text-small text-ink-muted md:text-body">{{ request.purpose }}</p>
          </div>
          <StatusBadge :status="request.status" class="shrink-0" />
        </div>

        <div class="mb-3 space-y-1.5 md:space-y-2">
          <div class="flex items-center justify-between">
            <span class="card-row-label md:text-body">Requested by</span>
            <span class="text-small text-ink md:text-body">{{ fullName(request.requested_by) }}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="card-row-label md:text-body">Travel date</span>
            <span class="text-small text-ink md:text-body">{{ formatDate(request.trip_date) }}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="card-row-label md:text-body">Departure</span>
            <span class="text-small text-ink md:text-body">{{ formatTime(request.departure_time) }}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="card-row-label md:text-body">Passengers</span>
            <span class="text-small text-ink md:text-body">{{ request.number_of_passengers ?? '—' }}</span>
          </div>
          <div
            v-if="request.status === 'disapproved' && request.disapproval_reason"
            class="flex items-start justify-between gap-3"
          >
            <span class="card-row-label shrink-0 md:text-body">Reason</span>
            <span class="text-right text-small text-red-700 md:text-body">
              {{ request.disapproval_reason }}
            </span>
          </div>
        </div>

        <div class="mt-auto flex gap-2 border-t border-line pt-3">
          <template v-if="auth.isAdministrator && request.status === 'pending'">
            <BaseButton size="sm" class="flex-1" @click="openApprove(request)">
              Approve
            </BaseButton>
            <BaseButton size="sm" variant="outline" class="flex-1" @click="openDisapprove(request)">
              Disapprove
            </BaseButton>
          </template>

          <BaseButton
            size="sm"
            variant="ghost"
            :class="hasOtherActions(request) ? '' : 'w-full'"
            @click="openRequest(request)"
          >
            View
          </BaseButton>
        </div>
      </div>
    </div>

    <!-- Laptop Table View (fits the screen, no side scrolling) -->
    <div
      v-if="!store.loading && store.items.length"
      class="hidden overflow-hidden rounded-card border border-line bg-white shadow-card lg:block"
    >
      <table class="w-full table-fixed border-collapse">
        <thead class="table-head">
          <tr>
            <th class="w-[18%] px-2 py-3 xl:px-card">Destination</th>
            <th class="w-[13%] px-2 py-3 xl:px-card">Requested by</th>
            <th class="w-[14%] px-2 py-3 xl:px-card">Travel</th>
            <th class="w-[6%] px-2 py-3 xl:px-card">Pax</th>
            <th class="w-[12%] px-2 py-3 xl:px-card">Status</th>
            <th class="w-[17%] px-2 py-3 xl:px-card">Reason</th>
            <th class="w-[20%] px-2 py-3 text-right xl:px-card">Actions</th>
          </tr>
        </thead>

        <tbody class="divide-y divide-line text-body">
          <tr
            v-for="request in store.items"
            :key="request.id"
            class="cursor-pointer hover:bg-neutral-50"
            tabindex="0"
            @click="onRowClick($event, request)"
            @keydown.enter="onRowClick($event, request)"
          >
            <td class="px-2 py-3 align-top xl:px-card">
              <RouterLink
                :to="{ name: 'requests.show', params: { id: request.id } }"
                class="font-medium hover:text-primary"
              >
                {{ request.destination }}
              </RouterLink>
              <p class="truncate text-small text-ink-muted">{{ request.purpose }}</p>
            </td>
            <td class="px-2 py-3 align-top text-small xl:px-card">
              {{ fullName(request.requested_by) }}
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
              <StatusBadge :status="request.status" />
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
              <div class="flex flex-wrap justify-end gap-1.5">
                <template v-if="auth.isAdministrator && request.status === 'pending'">
                  <BaseButton size="sm" @click="openApprove(request)">
                    Approve
                  </BaseButton>
                  <BaseButton size="sm" variant="outline" @click="openDisapprove(request)">
                    Disapprove
                  </BaseButton>
                </template>

                <BaseButton size="sm" variant="ghost" @click="openRequest(request)">
                  View
                </BaseButton>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <PaginationBar :meta="store.meta" @change="(page) => store.fetch({ page })" />
    </div>

    <!-- Pagination for the card view (mobile + tablet) -->
    <div
      v-if="!store.loading && store.items.length"
      class="overflow-hidden rounded-card border border-line bg-white lg:hidden"
    >
      <PaginationBar :meta="store.meta" @change="(page) => store.fetch({ page })" />
    </div>

    <ApproveAssignModal :request="approving" @close="approving = null" @done="onApproved" />

    <DisapproveRequestModal
      :request="disapproving"
      @close="disapproving = null"
      @done="onDisapproved"
    />
  </div>
</template>