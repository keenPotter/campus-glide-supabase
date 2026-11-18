<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { CalendarClock, CheckCircle2, ClipboardCheck, Eye, Pencil, Wrench } from 'lucide-vue-next'
import api, { errorMessage, unwrap, validationErrors } from '@/lib/api'
import { useNotificationStore } from '@/stores/notifications'
import { useToast } from '@/composables/useToast'
import {
  formatDate,
  formatKm,
  formatMoney,
  MAINTENANCE_TYPES,
  MONTH_OPTIONS,
  STATUS_LABELS,
  YEAR_OPTIONS,
  todayIso,
} from '@/lib/format'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import RefreshButton from '@/components/ui/RefreshButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import LoadError from '@/components/ui/LoadError.vue'
import PreventiveMaintenanceSection from '@/components/maintenance/PreventiveMaintenanceSection.vue'

const notifications = useNotificationStore()
const toast = useToast()

const PAGE_SIZE = 10
const today = todayIso()

const ICONS = {
  wrench:
    'M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94z',
  calendar:
    'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
  clock: 'M12 6v6l4 2M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z',
  alert:
    'M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0zM12 9v4M12 17h.01',
}

const TONES = {
  primary: 'bg-primary-50 text-primary-700',
  secondary: 'bg-secondary-50 text-secondary-700',
  danger: 'bg-red-50 text-red-700',
}

const statusOptions = ['completed', 'upcoming', 'overdue', 'in_progress', 'cancelled'].map(
  (value) => ({ value, label: STATUS_LABELS[value] }),
)

const formStatusOptions = ['scheduled', 'in_progress', 'completed', 'cancelled'].map((value) => ({
  value,
  label: STATUS_LABELS[value],
}))

/* ================= STATE ================= */

const logs = ref([])
const vehicles = ref([])
const vehiclesLoaded = ref(false)
const loading = ref(true)
const loadError = ref('')
const pageMeta = ref({ current_page: 1, last_page: 1, total: 0 })
const summary = ref({})

const search = ref('')
const fStatus = ref('')
const fVehicle = ref('')
const fType = ref('')
const fMonth = ref('')
const fYear = ref('')
const page = ref(1)

const showForm = ref(false)
const editingId = ref(null)
const detailsLog = ref(null)
const rescheduling = ref(null)
const rescheduleDate = ref('')
const rescheduleSaving = ref(false)
const earlyCompletionLog = ref(null)
const completingId = ref(null)
const checklistTarget = ref(null)
const saving = ref(false)
const errors = ref({})
const formError = ref('')
const form = ref(emptyForm())

/* ================= API ================= */

function toList(payload) {
  return Array.isArray(payload) ? payload : []
}

async function loadAll() {
  loading.value = true
  loadError.value = ''

  try {
    const params = {
      page: page.value,
      per_page: PAGE_SIZE,
      search: search.value,
      status: fStatus.value,
      vehicle_id: fVehicle.value,
      type: fType.value,
      month: fMonth.value,
      year: fYear.value,
    }
    const vehiclesRequest = vehiclesLoaded.value ? Promise.resolve(null) : api.get('/vehicles')
    const [logsResponse, vehiclesResponse] = await Promise.all([
      api.get('/maintenance-logs', { params }),
      vehiclesRequest,
    ])
    logs.value = toList(logsResponse.data?.data)
    pageMeta.value = logsResponse.data?.meta ?? pageMeta.value
    summary.value = logsResponse.data?.summary ?? {}
    if (vehiclesResponse) {
      vehicles.value = toList(unwrap(vehiclesResponse))
      vehiclesLoaded.value = true
    }
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load maintenance records.')
  } finally {
    loading.value = false
    notifications.refresh()
  }
}

onMounted(loadAll)

/* ================= DERIVED DATA ================= */

function displayStatus(log) {
  // A completed or cancelled record must never be reclassified by its next due date.
  if (log.status === 'completed') return 'completed'
  if (log.status === 'cancelled') return 'cancelled'
  if (log.status === 'in_progress') return 'in_progress'

  // For scheduled records, date_performed is the planned maintenance date.
  // next_due_date is the follow-up date after the maintenance is completed.
  if (log.status === 'scheduled') {
    return log.date_performed && log.date_performed < today ? 'overdue' : 'upcoming'
  }

  return 'upcoming'
}

function vehicleModel(vehicle) {
  return vehicle?.vehicle_model ?? vehicle?.model ?? 'Vehicle'
}

function typeLabel(type) {
  return MAINTENANCE_TYPES.find((item) => item.value === type)?.label ?? type
}

const rows = computed(() => logs.value.map((log) => ({ ...log, display: displayStatus(log) })))

const stats = computed(() => [
  { label: 'Total Maintenance', value: summary.value.total ?? 0, path: ICONS.wrench, tone: TONES.primary },
  {
    label: 'This Month',
    value: summary.value.this_month ?? 0,
    path: ICONS.calendar,
    tone: TONES.primary,
  },
  {
    label: 'Upcoming Maintenance',
    value: summary.value.upcoming ?? 0,
    path: ICONS.clock,
    tone: TONES.secondary,
  },
  {
    label: 'Overdue Maintenance',
    value: summary.value.overdue ?? 0,
    path: ICONS.alert,
    tone: TONES.danger,
  },
])

const vehicleFilterOptions = computed(() =>
  vehicles.value.map((vehicle) => ({ value: vehicle.id, label: vehicle.plate_number })),
)

const vehicleFormOptions = computed(() =>
  vehicles.value.map((vehicle) => ({
    value: vehicle.id,
    label: `${vehicle.plate_number} — ${vehicleModel(vehicle)}`,
  })),
)

const filtered = computed(() => {
  const query = search.value.trim().toLowerCase()

  return rows.value.filter((log) => {
    if (fStatus.value && log.display !== fStatus.value) return false
    if (fVehicle.value && String(log.vehicle?.id) !== String(fVehicle.value)) return false
    if (fType.value && log.type !== fType.value) return false
    if (fMonth.value && Number((log.date_performed || '').slice(5, 7)) !== Number(fMonth.value)) return false
    if (fYear.value && (log.date_performed || '').slice(0, 4) !== fYear.value) return false

    if (query) {
      const text = [log.vehicle?.plate_number, vehicleModel(log.vehicle), log.description, log.type]
        .join(' ')
        .toLowerCase()
      if (!text.includes(query)) return false
    }

    return true
  })
})

const pageItems = computed(() => filtered.value)
const paginationMeta = computed(() => pageMeta.value)

watch(search, (_, __, onCleanup) => {
  page.value = 1
  const timeout = setTimeout(loadAll, 250)
  onCleanup(() => clearTimeout(timeout))
})

watch([fStatus, fVehicle, fType, fMonth, fYear], () => {
  page.value = 1
  loadAll()
})

// Used by the card view (phones and tablets).
function metaOf(log) {
  return [
    { label: 'Date', value: formatDate(log.date_performed) },
    { label: 'Next due', value: formatDate(log.next_due_date) },
    { label: 'Odometer', value: formatKm(log.vehicle?.mileage) },
    { label: 'Cost', value: formatMoney(log.cost) },
  ]
}

/* ================= ACTIONS ================= */

function emptyForm() {
  return {
    vehicle_id: '',
    type: 'oil_change',
    description: '',
    date_performed: todayIso(),
    next_due_date: '',
    cost: '',
    status: 'scheduled',
  }
}

function openAdd() {
  editingId.value = null
  form.value = emptyForm()
  errors.value = {}
  formError.value = ''
  showForm.value = true
}

function openChecklist(log) {
  checklistTarget.value = log.vehicle
}

function closeChecklist() {
  checklistTarget.value = null
}

function openDetails(log) {
  detailsLog.value = log
}

function openEdit(log) {
  detailsLog.value = null
  editingId.value = log.id
  form.value = {
    vehicle_id: log.vehicle?.id ?? '',
    type: log.type,
    description: log.description || '',
    date_performed: log.date_performed,
    next_due_date: log.next_due_date || '',
    cost: log.cost ?? '',
    status: log.status || 'scheduled',
  }
  errors.value = {}
  formError.value = ''
  showForm.value = true
}

// Clicking anywhere on a row or card opens the edit form.
// Clicks on a button or link are skipped, so they keep doing their own job.
function onRowClick(event, log) {
  if (event.target.closest('a, button')) return
  openDetails(log)
}

function openReschedule(log) {
  rescheduling.value = log
  rescheduleDate.value = log.date_performed || today
}

async function saveReschedule() {
  if (!rescheduling.value || !rescheduleDate.value) return

  rescheduleSaving.value = true
  try {
    await api.patch(`/maintenance-logs/${rescheduling.value.id}`, {
      date_performed: rescheduleDate.value,
    })
    toast.success('Maintenance rescheduled.')
    rescheduling.value = null
    await loadAll()
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to reschedule this maintenance.'))
  } finally {
    rescheduleSaving.value = false
  }
}

async function save() {
  const f = form.value
  const problems = {}

  if (!f.vehicle_id) problems.vehicle_id = 'Please select a vehicle.'
  if (!f.date_performed) problems.date_performed = 'Please select a date.'
  if (f.next_due_date && f.next_due_date < f.date_performed) {
    problems.next_due_date = 'The next due date cannot be before the maintenance date.'
  }

  errors.value = problems
  formError.value = ''
  if (Object.keys(problems).length) return

  const payload = {
    vehicle_id: Number(f.vehicle_id),
    type: f.type,
    description: f.description || null,
    date_performed: f.date_performed,
    next_due_date: f.next_due_date || null,
    cost: f.cost === '' ? null : Number(f.cost),
    status: f.status,
  }

  saving.value = true
  try {
    if (editingId.value) {
      await api.patch(`/maintenance-logs/${editingId.value}`, payload)
    } else {
      await api.post('/maintenance-logs', payload)
    }
    toast.success(editingId.value ? 'Maintenance record updated.' : 'Maintenance record added.')
    showForm.value = false
    await loadAll()
  } catch (error) {
    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      formError.value = errorMessage(error, 'Unable to save this record.')
    }
  } finally {
    saving.value = false
  }
}

async function startMaintenance(log) {
  try {
    await api.patch(`/maintenance-logs/${log.id}`, { status: 'in_progress' })
    toast.success('Maintenance started.')
    await loadAll()
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to start this maintenance.'))
  }
}

function markCompleted(log) {
  if (log.date_performed > todayIso()) {
    earlyCompletionLog.value = log
    return
  }

  completeMaintenance(log)
}

async function completeMaintenance(log) {
  if (completingId.value !== null) return

  completingId.value = log.id
  try {
    await api.patch(`/maintenance-logs/${log.id}`, { status: 'completed' })
    toast.success('Marked as completed.')
    earlyCompletionLog.value = null
    await loadAll()
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to update this record.'))
  } finally {
    completingId.value = null
  }
}

function confirmEarlyCompletion() {
  if (earlyCompletionLog.value) {
    completeMaintenance(earlyCompletionLog.value)
  }
}
</script>

<template>
  <div class="flex flex-col gap-page">
    <!-- Page Header -->
    <div class="page-header">
      <div class="page-header-copy">
        <h1 class="text-page-title">Vehicle Maintenance</h1>
        <p class="mt-1 text-small text-ink-muted">Schedule, start, and track vehicle maintenance work</p>
      </div>
      <div class="page-actions">
        <RefreshButton :loading="loading" label="Refresh maintenance records" @click="loadAll" />
        <BaseButton size="sm" @click="openAdd">Add maintenance</BaseButton>
      </div>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <div v-for="stat in stats" :key="stat.label" class="stat-card">
        <span class="inline-flex h-10 w-10 items-center justify-center rounded-card" :class="stat.tone">
          <svg class="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path :d="stat.path" />
          </svg>
        </span>
        <p class="mt-3 text-page-title">{{ stat.value }}</p>
        <p class="text-small text-ink-muted">{{ stat.label }}</p>
      </div>
    </div>

    <!-- Search and filters -->
    <BaseCard>
      <div class="flex flex-col gap-3">
        <BaseInput v-model="search" type="search" placeholder="Search maintenance..." />

        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <BaseSelect v-model="fStatus" :options="statusOptions" placeholder="All status" allow-empty />
          <BaseSelect v-model="fVehicle" :options="vehicleFilterOptions" placeholder="All vehicles" allow-empty />
          <BaseSelect v-model="fType" :options="MAINTENANCE_TYPES" placeholder="All types" allow-empty />
          <BaseSelect v-model="fMonth" :options="MONTH_OPTIONS" placeholder="All months" allow-empty />
          <BaseSelect v-model="fYear" :options="YEAR_OPTIONS" placeholder="All years" allow-empty />
        </div>
      </div>
    </BaseCard>

    <LoadError :message="loadError" @retry="loadAll" />

    <!-- Records -->
    <BaseCard title="Maintenance records" subtitle="In progress first, then upcoming, overdue, cancelled and completed"
      :padded="false">
      <div v-if="loading" class="flex justify-center p-12">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <EmptyState v-else-if="!filtered.length" title="No maintenance records found"
        message="Get started by adding your first maintenance record.">
        <BaseButton class="mt-2" @click="openAdd">Add maintenance</BaseButton>
      </EmptyState>

      <template v-else>
        <!-- Card view stays in place until the table has room for its action buttons. -->
        <ul class="divide-y divide-line 2xl:hidden">
          <li v-for="log in pageItems" :key="log.id"
            class="flex cursor-pointer flex-col gap-2 p-card transition active:bg-neutral-50"
            @click="onRowClick($event, log)">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="font-medium text-ink">
                  {{ log.vehicle?.plate_number ?? '—' }}
                  <span class="font-normal text-ink-muted">· {{ vehicleModel(log.vehicle) }}</span>
                </p>
                <p class="mt-0.5 truncate text-small text-ink-muted">
                  {{ log.description || typeLabel(log.type) }}
                </p>
              </div>
              <StatusBadge :status="log.display" class="shrink-0" />
            </div>

            <dl class="grid grid-cols-2 gap-x-3 gap-y-2 sm:grid-cols-4">
              <div v-for="item in metaOf(log)" :key="item.label">
                <dt class="text-small text-ink-muted">{{ item.label }}</dt>
                <dd class="text-small font-medium text-ink">{{ item.value }}</dd>
              </div>
            </dl>

            <div class="grid grid-cols-2 items-center gap-2">
              <BaseButton class="w-full whitespace-nowrap" size="sm" variant="outline" @click="openChecklist(log)">
                <ClipboardCheck :size="16" aria-hidden="true" /> Checklist
              </BaseButton>
              <BaseButton v-if="log.status === 'scheduled'" class="w-full whitespace-nowrap" size="sm" variant="primary" @click="startMaintenance(log)">
                <Wrench :size="16" aria-hidden="true" /> Start maintenance
              </BaseButton>
              <BaseButton v-else-if="log.status === 'in_progress'" class="w-full whitespace-nowrap" size="sm" variant="success" :loading="completingId === log.id" @click="markCompleted(log)">
                <CheckCircle2 :size="16" aria-hidden="true" /> Complete
              </BaseButton>
              <BaseButton class="w-full whitespace-nowrap" size="sm" variant="outline" @click="openDetails(log)">
                <Eye :size="16" aria-hidden="true" /> View details
              </BaseButton>
              <BaseButton v-if="log.status === 'scheduled'" class="w-full whitespace-nowrap" size="sm" variant="outline" @click="openReschedule(log)">
                <CalendarClock :size="16" aria-hidden="true" /> Reschedule
              </BaseButton>
              <span v-else class="invisible" aria-hidden="true" />
            </div>
          </li>
        </ul>

        <!-- Wide-screen table view. Click a row to view details. -->
        <div class="hidden 2xl:block">
          <table class="w-full table-fixed border-collapse">
            <thead class="table-head">
              <tr>
                <th scope="col" class="w-[13%] px-2 py-3 xl:px-card">Vehicle</th>
                <th scope="col" class="w-[19%] px-2 py-3 xl:px-card">Description</th>
                <th scope="col" class="w-[9%] px-2 py-3 xl:px-card">Date</th>
                <th scope="col" class="w-[9%] px-2 py-3 xl:px-card">Next due</th>
                <th scope="col" class="w-[9%] px-2 py-3 xl:px-card">Odometer</th>
                <th scope="col" class="w-[8%] px-2 py-3 xl:px-card">Cost</th>
                <th scope="col" class="w-[9%] px-2 py-3 xl:px-card">Status</th>
                <th scope="col" class="w-[24%] px-2 py-3 text-right xl:px-card">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-line">
              <tr v-for="log in pageItems" :key="log.id" class="table-row-interactive" tabindex="0"
                @click="onRowClick($event, log)" @keydown.enter="onRowClick($event, log)">
                <td class="px-2 py-3 align-top xl:px-card">
                  <p class="font-medium text-ink">{{ log.vehicle?.plate_number ?? '—' }}</p>
                  <p class="truncate text-small text-ink-muted">{{ vehicleModel(log.vehicle) }}</p>
                </td>
                <td class="px-2 py-3 align-top text-small xl:px-card">
                  <p class="line-clamp-3 break-words text-ink">{{ log.description || typeLabel(log.type) }}</p>
                  <p class="text-ink-muted">{{ typeLabel(log.type) }}</p>
                </td>
                <td class="px-2 py-3 align-top text-small xl:px-card">{{ formatDate(log.date_performed) }}</td>
                <td class="px-2 py-3 align-top text-small xl:px-card">{{ formatDate(log.next_due_date) }}</td>
                <td class="px-2 py-3 align-top text-small xl:px-card">{{ formatKm(log.vehicle?.mileage) }}</td>
                <td class="px-2 py-3 align-top text-small xl:px-card">{{ formatMoney(log.cost) }}</td>
                <td class="px-2 py-3 align-top xl:px-card"><StatusBadge :status="log.display" /></td>
                <td class="px-2 py-3 align-top xl:px-card">
                  <div class="grid grid-cols-2 items-center gap-1.5">
                    <BaseButton class="w-full whitespace-nowrap" size="sm" variant="outline" @click="openChecklist(log)">
                      <ClipboardCheck :size="16" aria-hidden="true" /> Checklist
                    </BaseButton>
                    <BaseButton v-if="log.status === 'scheduled'" class="w-full whitespace-nowrap" size="sm" variant="primary" @click="startMaintenance(log)">
                      <Wrench :size="16" aria-hidden="true" /> Start
                    </BaseButton>
                    <BaseButton v-else-if="log.status === 'in_progress'" class="w-full whitespace-nowrap" size="sm" variant="success" :loading="completingId === log.id" @click="markCompleted(log)">
                      <CheckCircle2 :size="16" aria-hidden="true" /> Complete
                    </BaseButton>
                    <BaseButton class="w-full whitespace-nowrap" size="sm" variant="outline" @click="openDetails(log)">
                      <Eye :size="16" aria-hidden="true" /> Details
                    </BaseButton>
                    <BaseButton v-if="log.status === 'scheduled'" class="w-full whitespace-nowrap" size="sm" variant="outline" @click="openReschedule(log)">
                      <CalendarClock :size="16" aria-hidden="true" /> Reschedule
                    </BaseButton>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>

      <PaginationBar v-if="!loading" :meta="paginationMeta" @change="(value) => { page = value; loadAll() }" />
    </BaseCard>

    <PreventiveMaintenanceSection
      v-if="checklistTarget"
      :vehicles="[checklistTarget]"
      :selected-vehicle-id="checklistTarget.id"
      auto-assess
      modal-only
      @close="closeChecklist"
    />

    <BaseModal
      :open="Boolean(detailsLog)"
      title="Maintenance details"
      :subtitle="detailsLog ? `${detailsLog.vehicle?.plate_number ?? 'Vehicle'} — ${vehicleModel(detailsLog.vehicle)}` : ''"
      @close="detailsLog = null"
    >
      <dl v-if="detailsLog" class="grid gap-4 sm:grid-cols-2">
        <div><dt class="text-small text-ink-muted">Description</dt><dd class="font-medium">{{ detailsLog.description || typeLabel(detailsLog.type) }}</dd></div>
        <div><dt class="text-small text-ink-muted">Work type</dt><dd class="font-medium">{{ typeLabel(detailsLog.type) }}</dd></div>
        <div><dt class="text-small text-ink-muted">Date</dt><dd class="font-medium">{{ formatDate(detailsLog.date_performed) }}</dd></div>
        <div v-if="detailsLog.completion_date"><dt class="text-small text-ink-muted">Completed on</dt><dd class="font-medium">{{ formatDate(detailsLog.completion_date) }}</dd></div>
        <div><dt class="text-small text-ink-muted">Next due</dt><dd class="font-medium">{{ formatDate(detailsLog.next_due_date) }}</dd></div>
        <div><dt class="text-small text-ink-muted">Odometer</dt><dd class="font-medium">{{ formatKm(detailsLog.vehicle?.mileage) }}</dd></div>
        <div><dt class="text-small text-ink-muted">Cost</dt><dd class="font-medium">{{ formatMoney(detailsLog.cost) }}</dd></div>
        <div><dt class="text-small text-ink-muted">Status</dt><dd><StatusBadge :status="detailsLog.display" /></dd></div>
      </dl>
      <template #footer>
        <BaseButton variant="outline" @click="detailsLog = null">Close</BaseButton>
        <BaseButton @click="openEdit(detailsLog)"><Pencil :size="16" aria-hidden="true" /> Edit</BaseButton>
      </template>
    </BaseModal>

    <BaseModal
      :open="Boolean(rescheduling)"
      title="Reschedule maintenance"
      :subtitle="rescheduling ? `${rescheduling.vehicle?.plate_number ?? 'Vehicle'} — ${vehicleModel(rescheduling.vehicle)}` : ''"
      @close="rescheduling = null"
    >
      <BaseInput v-model="rescheduleDate" label="New maintenance date" type="date" required />
      <template #footer>
        <BaseButton variant="outline" @click="rescheduling = null">Cancel</BaseButton>
        <BaseButton :loading="rescheduleSaving" @click="saveReschedule">Save date</BaseButton>
      </template>
    </BaseModal>

    <BaseModal
      :open="Boolean(earlyCompletionLog)"
      title="Complete maintenance early?"
      @close="earlyCompletionLog = null"
    >
      <p v-if="earlyCompletionLog">
        Complete this maintenance early? It is scheduled for {{ formatDate(earlyCompletionLog.date_performed) }}.
      </p>
      <template #footer>
        <BaseButton variant="outline" :disabled="completingId !== null" @click="earlyCompletionLog = null">
          Cancel
        </BaseButton>
        <BaseButton
          variant="success"
          :loading="completingId === earlyCompletionLog?.id"
          @click="confirmEarlyCompletion"
        >
          Complete Now
        </BaseButton>
      </template>
    </BaseModal>

    <!-- Add / edit modal -->
    <BaseModal :open="showForm" :title="editingId ? 'Edit maintenance' : 'Add maintenance'"
      subtitle="Maintenance record" @close="showForm = false">
      <div class="flex flex-col gap-4">
        <p class="rounded-card border-l-4 border-secondary bg-secondary-50 p-3 text-small text-secondary-700">
          For scheduled work, Date is the planned maintenance date. Next due is the follow-up date after completion.
        </p>

        <BaseSelect v-model="form.vehicle_id" label="Vehicle" placeholder="Select vehicle" :options="vehicleFormOptions"
          :error="errors.vehicle_id" required />

        <BaseSelect v-model="form.type" label="Work type" :options="MAINTENANCE_TYPES" :error="errors.type" required />

        <BaseTextarea v-model="form.description" label="Description" placeholder="What work is being done?"
          :error="errors.description" />

        <div class="grid gap-4 sm:grid-cols-2">
          <BaseInput v-model="form.date_performed" label="Date" type="date" :error="errors.date_performed" required />
          <BaseInput v-model="form.next_due_date" label="Next due" type="date" :min="form.date_performed"
            :error="errors.next_due_date" />
          <BaseInput v-model="form.cost" label="Cost (₱)" type="number" min="0" step="0.01" placeholder="0.00"
            :error="errors.cost" />
          <BaseSelect v-model="form.status" label="Status" :options="formStatusOptions" :error="errors.status"
            required />
        </div>

        <p v-if="formError" class="rounded-card bg-red-50 p-3 text-small font-medium text-red-700">
          {{ formError }}
        </p>
      </div>

      <template #footer>
        <BaseButton variant="outline" @click="showForm = false">Cancel</BaseButton>
        <BaseButton :loading="saving" @click="save">Save</BaseButton>
      </template>
    </BaseModal>
  </div>
</template>