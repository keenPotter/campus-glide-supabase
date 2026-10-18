<script setup>
import { computed, ref, watch } from 'vue'
import { useAllocations } from '@/composables/useAllocations'
import { useToast } from '@/composables/useToast'
import { useNotificationStore } from '@/stores/notifications'
import { formatDate } from '@/lib/format'
import { canPrint, canReassign, passengerText, requestNumber, whenText } from '@/lib/allocations'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import LoadError from '@/components/ui/LoadError.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import TripTypeBadge from '@/components/ui/TripTypeBadge.vue'
import AllocationModal from '@/components/allocations/AllocationModal.vue'
import ConflictModal from '@/components/allocations/ConflictModal.vue'
import DateChangeDecisionModal from '@/components/allocations/DateChangeDecisionModal.vue'
import PrintableTripRequest from '@/components/allocations/PrintableTripRequest.vue'
import QuickAddModal from '@/components/allocations/QuickAddModal.vue'
import RescheduleRequestCard from '@/components/allocations/RescheduleRequestCard.vue'

// The allocation page for administrators.
// New allocations are made when a vehicle request is approved (Vehicle Requests page).
const toast = useToast()
const notifications = useNotificationStore()

const {
  waiting,
  admins,
  loading,
  loadError,
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
} = useAllocations()

const PAGE_SIZE = 10

const search = ref('')
const typeFilter = ref('')
const monthFilter = ref('') // '' = all months, '01' to '12'
const yearFilter = ref('') // '' = all years, for example '2026'
const page = ref(1)

const modalOpen = ref(false)
const editing = ref(null)
// Conflicts found when a date change request was approved (vehicle and driver together).
const pageConflicts = ref([])
const printTarget = ref(null)
const printNotice = ref('')

// 'vehicle' or 'driver' while the "Add" window is open.
const quickAdd = ref('')

// The faculty date change request the administrator is deciding on.
const decisionItem = ref(null)
const decisionAction = ref('')

const tones = {
  primary: 'bg-primary-50 text-primary-700',
  secondary: 'bg-secondary-50 text-secondary-700',
}

const stats = computed(() => [
  { label: 'Scheduled', value: counts.value.scheduled, tone: 'primary' },
  { label: 'Ongoing', value: counts.value.in_progress, tone: 'secondary' },
  { label: 'Done', value: counts.value.completed, tone: 'primary' },
  { label: 'Needs allocation', value: waiting.value.length, tone: 'secondary' },
])

// Availability is for today.
const dotClass = { green: 'bg-primary', orange: 'bg-secondary', red: 'bg-red-500' }
const dotLabel = { green: 'Available', orange: 'Scheduled today', red: 'On a trip now' }

const kindLabel = {
  allocation: 'Allocation',
  waiting: 'Needs allocation',
  received: 'Received request',
}

// The first conflicted trip that can still be reassigned (scheduled trips only).
const resolvableConflict = computed(() =>
  conflictedAllocations.value.find((allocation) => canReassign(allocation)),
)

/* ================= SUMMARY ================= */

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

const monthOptions = MONTHS.map((name, index) => ({
  value: String(index + 1).padStart(2, '0'),
  label: name,
}))

// Years that have a trip. The current year is always there.
const yearOptions = computed(() => {
  const years = new Set([String(new Date().getFullYear())])

  summaryRows.value.forEach((row) => {
    const year = String(row.date ?? '').slice(0, 4)
    if (/^\d{4}$/.test(year)) years.add(year)
  })

  return [...years].sort((a, b) => b.localeCompare(a)).map((year) => ({ value: year, label: year }))
})

// Rows that match the Month and Year filters (the trip date is YYYY-MM-DD).
const dateRows = computed(() =>
  summaryRows.value.filter((row) => {
    const date = String(row.date ?? '')
    if (yearFilter.value && date.slice(0, 4) !== yearFilter.value) return false
    if (monthFilter.value && date.slice(5, 7) !== monthFilter.value) return false
    return true
  }),
)

function countOf(type) {
  return dateRows.value.filter((row) => row.tripType === type).length
}

const typeOptions = computed(() => [
  { value: '', label: `All (${dateRows.value.length})` },
  { value: 'inclusive', label: `Inclusive (${countOf('inclusive')})`, dot: 'bg-primary' },
  { value: 'exclusive', label: `Exclusive (${countOf('exclusive')})`, dot: 'bg-secondary' },
])

// The trip type is the one the faculty member chose on the request form.
// The order of the rows is set in useAllocations.
const visibleRows = computed(() => {
  const query = search.value.trim().toLowerCase()

  return dateRows.value.filter((row) => {
    if (typeFilter.value && row.tripType !== typeFilter.value) return false
    if (!query) return true

    const item = row.allocation
    return [
      row.destination,
      row.requester,
      item?.driver?.name,
      item?.vehicle?.plate_number,
      item?.vehicle?.vehicle_model,
    ]
      .join(' ')
      .toLowerCase()
      .includes(query)
  })
})

/* ================= PAGINATION ================= */

const pageCount = computed(() => Math.max(1, Math.ceil(visibleRows.value.length / PAGE_SIZE)))

const pageRows = computed(() =>
  visibleRows.value.slice((page.value - 1) * PAGE_SIZE, page.value * PAGE_SIZE),
)

const paginationMeta = computed(() => ({
  current_page: page.value,
  last_page: pageCount.value,
  total: visibleRows.value.length,
}))

// Go back to the first page when the search or filter changes.
watch([search, typeFilter, monthFilter, yearFilter], () => {
  page.value = 1
})

// If the list gets shorter (for example after a reload), stay on a page that exists.
watch(pageCount, (count) => {
  if (page.value > count) page.value = count
})

/* ================= ACTIONS ================= */

// Reload the page data and the menu badges.
async function reload() {
  await load()
  notifications.refresh()
}

function openEdit(allocation) {
  editing.value = allocation
  modalOpen.value = true
}

function onSaved() {
  modalOpen.value = false
  reload()
  toast.success('Allocation updated.')
}

function openPrint(allocation, notice = '') {
  printNotice.value = notice
  printTarget.value = allocation
}

// Clicking anywhere on a row opens the View / Print window (when printing is allowed).
// Clicks on a button or link keep doing their own job.
function onRowClick(event, row) {
  if (event.target.closest('a, button')) return

  if (canPrint(row.allocation)) {
    openPrint(row.allocation)
  }
}

function onQuickAdded({ kind, item }) {
  if (kind === 'driver') {
    addDriver(item)
    toast.success('Driver added.')
  } else {
    addVehicle(item)
    toast.success('Vehicle added.')
  }
  quickAdd.value = ''
}

function decide(item, action) {
  decisionItem.value = item
  decisionAction.value = action
}

function closeDecision() {
  decisionItem.value = null
  decisionAction.value = ''
}

function onDecided(message) {
  closeDecision()
  toast.success(message)
  reload()
}

// The requested date is already booked: close the decision window and show the conflicts.
function onDecisionConflict(found) {
  closeDecision()
  pageConflicts.value = found
}
</script>

<template>
  <div class="flex flex-col gap-page">
    <!-- Header -->
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-page-title">Vehicle-Driver Allocation</h1>
        <p class="mt-1 text-small text-ink-muted">
          A vehicle and driver are assigned when a vehicle request is approved. Scheduling conflicts
          are flagged automatically.
        </p>
      </div>
      <BaseButton variant="outline" size="sm" :disabled="loading" @click="reload">Refresh</BaseButton>
    </div>

    <LoadError :message="loadError" @retry="reload" />

    <!-- Conflict banner -->
    <div
      v-if="conflictedAllocations.length"
      role="alert"
      class="flex flex-wrap items-center justify-between gap-3 rounded-card border border-red-200 bg-red-50 p-card text-small text-red-800"
    >
      <p class="min-w-0 flex-1 font-medium">
        {{ conflictTexts.length }} conflict{{ conflictTexts.length > 1 ? 's' : '' }} detected:
        {{ conflictTexts.join(' · ') }}. Please resolve before confirming the schedule.
      </p>
      <BaseButton
        v-if="resolvableConflict"
        size="sm"
        variant="outline"
        @click="openEdit(resolvableConflict)"
      >
        Resolve
      </BaseButton>
    </div>

    <!-- Vehicles and drivers -->
    <div class="grid grid-cols-1 gap-page lg:grid-cols-2">
      <BaseCard title="Vehicles" subtitle="Availability today" :padded="false">
        <template #actions>
          <BaseButton size="sm" @click="quickAdd = 'vehicle'">+ Add vehicle</BaseButton>
        </template>

        <EmptyState v-if="!loading && !vehicleList.length" title="No vehicles found" />
        <ul v-else class="max-h-80 divide-y divide-line overflow-y-auto">
          <li v-for="item in vehicleList" :key="item.id" class="flex items-center gap-3 px-card py-3">
            <div class="min-w-0 flex-1">
              <p class="truncate text-small font-medium text-ink">
                {{ item.vehicle_model }} · {{ item.plate_number }}
              </p>
              <p class="text-small text-ink-muted">Capacity: {{ item.capacity ?? '—' }}</p>
            </div>
            <span
              class="h-2.5 w-2.5 shrink-0 rounded-full"
              :class="dotClass[item.state]"
              :title="dotLabel[item.state]"
              :aria-label="dotLabel[item.state]"
            />
          </li>
        </ul>
      </BaseCard>

      <BaseCard title="Drivers" subtitle="Availability today" :padded="false">
        <template #actions>
          <BaseButton size="sm" @click="quickAdd = 'driver'">+ Add driver</BaseButton>
        </template>

        <EmptyState v-if="!loading && !driverList.length" title="No drivers found" />
        <ul v-else class="max-h-80 divide-y divide-line overflow-y-auto">
          <li v-for="item in driverList" :key="item.id" class="flex items-center gap-3 px-card py-3">
            <div class="min-w-0 flex-1">
              <p class="truncate text-small font-medium text-ink">{{ item.name }}</p>
              <p class="truncate text-small text-ink-muted">
                {{ item.contact_number || 'No contact number'
                }}{{ item.license_expiry_date ? ` · Lic. exp. ${formatDate(item.license_expiry_date)}` : '' }}
              </p>
            </div>
            <span
              class="h-2.5 w-2.5 shrink-0 rounded-full"
              :class="dotClass[item.state]"
              :title="dotLabel[item.state]"
              :aria-label="dotLabel[item.state]"
            />
          </li>
        </ul>
      </BaseCard>
    </div>

    <p class="flex flex-wrap gap-4 text-small text-ink-muted">
      <span v-for="(label, key) in dotLabel" :key="key" class="inline-flex items-center gap-1.5">
        <i class="h-2.5 w-2.5 rounded-full" :class="dotClass[key]" /> {{ label }}
      </span>
    </p>

    <!-- Stats -->
    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
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

    <!-- Date change requests from faculty -->
    <BaseCard
      v-if="pendingDateChanges.length"
      title="Date change requests"
      :subtitle="`${pendingDateChanges.length} waiting for your decision`"
    >
      <div class="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <RescheduleRequestCard
          v-for="item in pendingDateChanges"
          :key="item.id"
          :item="item"
          is-admin
          @approve="decide($event, 'approve')"
          @disapprove="decide($event, 'disapprove')"
        />
      </div>
    </BaseCard>

    <!-- Allocation summary -->
    <BaseCard title="Allocation summary" :padded="false">
      <div class="flex flex-col gap-3 border-b border-line p-card">
        <BaseInput
          v-model="search"
          type="search"
          placeholder="Search by destination, requester, driver or plate..."
        />
        <SegmentedControl v-model="typeFilter" :options="typeOptions" label="Trip type" />
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <BaseSelect
            v-model="monthFilter"
            label="Month"
            placeholder="All months"
            allow-empty
            :options="monthOptions"
          />
          <BaseSelect
            v-model="yearFilter"
            label="Year"
            placeholder="All years"
            allow-empty
            :options="yearOptions"
          />
        </div>
      </div>

      <div v-if="loading" class="flex justify-center p-12">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <EmptyState
        v-else-if="!visibleRows.length"
        title="Nothing found"
        :message="
          typeFilter || search || monthFilter || yearFilter
            ? 'No requests match your filters.'
            : 'Approved requests and allocations will appear here.'
        "
      />

      <ul v-else class="divide-y divide-line">
        <li
          v-for="row in pageRows"
          :key="row.key"
          class="flex cursor-pointer flex-col gap-3 p-card transition hover:bg-neutral-50 lg:flex-row lg:items-center"
          tabindex="0"
          @click="onRowClick($event, row)"
          @keydown.enter="onRowClick($event, row)"
        >
          <!-- Trip -->
          <div class="min-w-0 lg:w-1/4">
            <p class="truncate font-medium text-ink">
              {{ requestNumber(row.requestId ?? row.allocation?.id) }} · {{ row.destination ?? '—' }}
            </p>
            <p class="truncate text-small text-ink-muted">
              <template v-if="row.kind === 'received'">Sent by {{ row.share.sender.name }}</template>
              <template v-else>{{ row.requester ?? '—' }}</template>
            </p>
            <div class="mt-1.5 flex flex-wrap items-center gap-2">
              <span class="text-small text-ink-muted">{{ kindLabel[row.kind] }}</span>
              <TripTypeBadge :type="row.tripType" />
              <StatusBadge v-if="row.allocation" :status="row.allocation.status ?? 'scheduled'" />
            </div>
          </div>

          <!-- Vehicle and driver -->
          <div class="min-w-0 text-small lg:w-1/4">
            <template v-if="row.allocation">
              <p class="truncate text-ink">
                {{ row.allocation.vehicle?.vehicle_model ?? '—' }} ·
                {{ row.allocation.vehicle?.plate_number ?? '—' }}
              </p>
              <p class="truncate text-ink-muted">{{ row.allocation.driver?.name ?? '—' }}</p>
            </template>
            <p v-else class="italic text-ink-muted">Not yet assigned</p>
          </div>

          <!-- Date and conflict -->
          <div class="min-w-0 text-small lg:flex-1">
            <p class="text-ink">{{ whenText(row.date, row.time) }}</p>
            <p v-if="row.allocation && pendingByAllocation[row.allocation.id]" class="text-secondary-700">
              Date change requested: {{ formatDate(pendingByAllocation[row.allocation.id].new_date) }}
            </p>
            <p
              v-if="row.allocation"
              class="font-medium"
              :class="conflicts[row.allocation.id] ? 'text-red-600' : 'text-primary-700'"
            >
              {{ conflicts[row.allocation.id] ? '⚠ Conflict' : '✓ No conflict' }}
            </p>
          </div>

          <!-- Number of passengers -->
          <div class="min-w-0 text-small lg:w-28">
            <p class="text-ink">{{ passengerText(row.passengers) }}</p>
          </div>

          <!-- Actions -->
          <div class="flex flex-wrap gap-2 lg:justify-end">
            <template v-if="row.kind === 'allocation'">
              <!-- Reassign is for scheduled trips only. It turns red when there is a conflict. -->
              <BaseButton
                v-if="canReassign(row.allocation)"
                size="sm"
                :variant="conflicts[row.allocation.id] ? 'danger' : 'outline'"
                @click="openEdit(row.allocation)"
              >
                Reassign
              </BaseButton>
              <!-- Printing is available only for an approved request with a vehicle and driver assigned. -->
              <BaseButton
                v-if="canPrint(row.allocation)"
                size="sm"
                variant="ghost"
                @click="openPrint(row.allocation)"
              >
                View / Print
              </BaseButton>
            </template>

            <BaseButton
              v-else-if="canPrint(row.allocation)"
              size="sm"
              variant="outline"
              @click="openPrint(row.allocation)"
            >
              View / Print
            </BaseButton>
          </div>
        </li>
      </ul>

      <PaginationBar v-if="!loading" :meta="paginationMeta" @change="(value) => (page = value)" />
    </BaseCard>

    <AllocationModal
      :open="modalOpen"
      :allocation="editing"
      @close="modalOpen = false"
      @saved="onSaved"
    />

    <QuickAddModal :kind="quickAdd" @close="quickAdd = ''" @created="onQuickAdded" />

    <DateChangeDecisionModal
      :item="decisionItem"
      :action="decisionAction"
      @close="closeDecision"
      @saved="onDecided"
      @conflict="onDecisionConflict"
    />

    <PrintableTripRequest
      :allocation="printTarget"
      :notice="printNotice"
      :admins="admins"
      @close="printTarget = null"
      @sent="reload"
    />

    <ConflictModal
      :conflicts="pageConflicts"
      hint="Please choose another date."
      @close="pageConflicts = []"
    />
  </div>
</template>