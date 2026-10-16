<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import api, { errorMessage, unwrap, validationErrors } from '@/lib/api'
import { formatDate, todayIso } from '@/lib/format'
import { printHtml } from '@/lib/printHtml'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'

// The maintenance checklist: every vehicle of the motorpool is listed.
// The administrator clicks "Assess" on a vehicle, fills in the checklist and prints it.
// Printing saves the checklist as a record first (so the history is kept),
// then the form goes back to blank so it can be used again for the next assessment.
const props = defineProps({
  vehicles: { type: Array, default: () => [] },
})

const toast = useToast()

const PAGE_SIZE = 10

const records = ref([])
const loading = ref(true)
const loadError = ref('')
const search = ref('')
const page = ref(1)

const showForm = ref(false)
const assessing = ref(null)
const saving = ref(false)
const errors = ref({})
const formError = ref('')

const DATE_FIELDS = [
  { field: 'last_oil_change', label: 'Last oil change' },
  { field: 'last_air_filter_change', label: 'Last air filter change' },
  { field: 'last_cabin_filter_change', label: 'Last cabin filter change' },
  { field: 'last_oil_filter_change', label: 'Last oil filter change' },
  { field: 'last_engine_tune_up', label: 'Last engine tune-up' },
]

const CONDITION_FIELDS = [
  { field: 'belts_condition', label: 'Belts' },
  { field: 'hoses_condition', label: 'Hoses' },
  { field: 'engine_condition', label: 'Engine' },
  { field: 'air_conditioning_condition', label: 'Air conditioning' },
  { field: 'wipers_condition', label: 'Wipers' },
  { field: 'headlights_condition', label: 'Headlights' },
  { field: 'driving_lights_condition', label: 'Driving lights' },
  { field: 'brake_lights_condition', label: 'Brake lights' },
  { field: 'hazard_lights_condition', label: 'Hazard lights' },
  { field: 'door_locks_condition', label: 'Door locks' },
  { field: 'windows_windshield_condition', label: 'Windows / windshield' },
  { field: 'radio_condition', label: 'Radio' },
  { field: 'tires_condition', label: 'Tires' },
  { field: 'liquid_levels_condition', label: 'Liquid levels' },
]

const ratingOptions = [
  { value: 'excellent', label: 'Excellent' },
  { value: 'good', label: 'Good' },
  { value: 'poor', label: 'Poor' },
]

// The blank form. Used every time the Assess window opens and after printing.
function emptyForm() {
  return {
    pmuv_no: '',
    inspection_date: todayIso(),
    inspector_mechanic: '',
    current_mileage: '',
    last_oil_change: '',
    last_air_filter_change: '',
    last_cabin_filter_change: '',
    last_oil_filter_change: '',
    last_engine_tune_up: '',
    ...Object.fromEntries(CONDITION_FIELDS.map(({ field }) => [field, ''])),
    other_parts: '',
    remarks: '',
    supervisor_recommendation: '',
  }
}

const form = ref(emptyForm())

/* ================= DATA ================= */

onMounted(loadRecords)

async function loadRecords() {
  loading.value = true
  loadError.value = ''
  try {
    const response = await api.get('/preventive-maintenance-checklists')
    const payload = unwrap(response)
    records.value = Array.isArray(payload) ? payload : []
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load preventive maintenance checklists.')
  } finally {
    loading.value = false
  }
}

function modelOf(vehicle) {
  return vehicle?.vehicle_model ?? vehicle?.model ?? '—'
}

// vehicle id -> date of its latest saved checklist
const lastInspection = computed(() => {
  const latest = {}

  for (const record of records.value) {
    const id = record.vehicle?.id
    if (!id || !record.inspection_date) continue
    if (!latest[id] || record.inspection_date > latest[id]) latest[id] = record.inspection_date
  }

  return latest
})

const filtered = computed(() => {
  const query = search.value.trim().toLowerCase()

  return props.vehicles
    .map((vehicle) => ({ ...vehicle, lastInspection: lastInspection.value[vehicle.id] ?? null }))
    .filter((vehicle) => {
      if (!query) return true
      return [vehicle.plate_number, modelOf(vehicle)].join(' ').toLowerCase().includes(query)
    })
})

const pageCount = computed(() => Math.max(1, Math.ceil(filtered.value.length / PAGE_SIZE)))
const pageItems = computed(() =>
  filtered.value.slice((page.value - 1) * PAGE_SIZE, page.value * PAGE_SIZE),
)
const paginationMeta = computed(() => ({
  current_page: page.value,
  last_page: pageCount.value,
  total: filtered.value.length,
}))

watch(search, () => {
  page.value = 1
})

watch(pageCount, (count) => {
  if (page.value > count) page.value = count
})

/* ================= ACTIONS ================= */

function openAssess(vehicle) {
  assessing.value = vehicle
  form.value = emptyForm()
  errors.value = {}
  formError.value = ''
  showForm.value = true
}

// Clicking anywhere on a row or card opens the assessment.
// Clicks on a button or link are skipped, so they keep doing their own job.
function onRowClick(event, vehicle) {
  if (event.target.closest('a, button')) return
  openAssess(vehicle)
}

function closeForm() {
  showForm.value = false
  assessing.value = null
}

// Saves the checklist, prints it, and resets the form so it can be used again.
async function printAssessment() {
  errors.value = {}
  formError.value = ''

  if (!form.value.inspection_date) {
    errors.value.inspection_date = 'Please select an inspection date.'
    return
  }

  const payload = {
    ...form.value,
    vehicle_id: assessing.value.id,
    current_mileage: form.value.current_mileage === '' ? null : Number(form.value.current_mileage),
  }

  saving.value = true
  try {
    const created = unwrap(await api.post('/preventive-maintenance-checklists', payload))

    // The printable form is built by the backend (legal size).
    const { data: html } = await api.get(`/preventive-maintenance-checklists/${created.id}/print`, {
      responseType: 'text',
      headers: { Accept: 'text/html' },
    })

    closeForm()
    form.value = emptyForm()
    toast.success('Checklist saved. Opening the print window.')
    printHtml(html)
    await loadRecords()
  } catch (error) {
    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      formError.value = errorMessage(error, 'Unable to save and print this checklist.')
    }
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <BaseCard
    title="Maintenance checklist"
    subtitle="Click a vehicle to assess it, then print the monthly checklist"
    :padded="false"
  >
    <div class="border-b border-line p-card">
      <BaseInput v-model="search" type="search" placeholder="Search by plate number or model..." />
    </div>

    <div v-if="loadError" class="m-card rounded-card bg-red-50 p-3 text-small text-red-700">
      {{ loadError }}
      <button type="button" class="ml-2 font-semibold underline" @click="loadRecords">Retry</button>
    </div>

    <div v-if="loading" class="flex justify-center p-12">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
    </div>

    <EmptyState
      v-else-if="!filtered.length"
      title="No vehicles found"
      :message="search ? 'No vehicles match your search.' : 'Vehicles of the motorpool will appear here.'"
    />

    <template v-else>
      <!-- Card view (phones and tablets). Tap a card to assess it. -->
      <ul class="divide-y divide-line lg:hidden">
        <li
          v-for="vehicle in pageItems"
          :key="vehicle.id"
          class="flex cursor-pointer flex-col gap-2 p-card transition active:bg-neutral-50"
          @click="onRowClick($event, vehicle)"
        >
          <div class="min-w-0">
            <p class="font-medium text-ink">
              {{ vehicle.plate_number }}
              <span class="font-normal text-ink-muted">· {{ modelOf(vehicle) }}</span>
            </p>
          </div>

          <dl>
            <dt class="text-small text-ink-muted">Last inspection</dt>
            <dd class="text-small font-medium text-ink">
              {{ vehicle.lastInspection ? formatDate(vehicle.lastInspection) : 'No inspection yet' }}
            </dd>
          </dl>

          <div class="flex justify-end gap-2">
            <BaseButton size="sm" variant="secondary" @click="openAssess(vehicle)">Assess</BaseButton>
          </div>
        </li>
      </ul>

      <!-- Table view (laptops and larger). Click a row to assess it. -->
      <div class="hidden lg:block">
        <table class="w-full table-fixed border-collapse">
          <thead class="table-head">
            <tr>
              <th class="w-[25%] px-2 py-3 xl:px-card">Plate number</th>
              <th class="w-[30%] px-2 py-3 xl:px-card">Model</th>
              <th class="w-[25%] px-2 py-3 xl:px-card">Last inspection</th>
              <th class="w-[20%] px-2 py-3 text-right xl:px-card">Actions</th>
            </tr>
          </thead>

          <tbody class="divide-y divide-line">
            <tr
              v-for="vehicle in pageItems"
              :key="vehicle.id"
              class="cursor-pointer hover:bg-neutral-50"
              tabindex="0"
              @click="onRowClick($event, vehicle)"
              @keydown.enter="onRowClick($event, vehicle)"
            >
              <td class="px-2 py-3 align-top xl:px-card">
                <p class="font-medium text-ink">{{ vehicle.plate_number }}</p>
              </td>
              <td class="px-2 py-3 align-top text-small xl:px-card">{{ modelOf(vehicle) }}</td>
              <td class="px-2 py-3 align-top text-small xl:px-card">
                {{ vehicle.lastInspection ? formatDate(vehicle.lastInspection) : 'No inspection yet' }}
              </td>
              <td class="px-2 py-3 align-top xl:px-card">
                <div class="flex flex-wrap justify-end gap-1.5">
                  <BaseButton size="sm" variant="primary" @click="openAssess(vehicle)">Assess</BaseButton>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <PaginationBar v-if="!loading" :meta="paginationMeta" @change="(value) => (page = value)" />

    <BaseModal
      :open="showForm"
      title="Assess vehicle"
      :subtitle="assessing ? `${assessing.plate_number} — ${modelOf(assessing)}` : ''"
      @close="closeForm"
    >
      <div class="flex flex-col gap-4">
        <div class="grid gap-4 sm:grid-cols-2">
          <BaseInput v-model="form.pmuv_no" label="PMUV No." :error="errors.pmuv_no" />
          <BaseInput
            v-model="form.inspection_date"
            label="Inspection date"
            type="date"
            :error="errors.inspection_date"
            required
          />
          <BaseInput
            v-model="form.inspector_mechanic"
            label="Inspector / mechanic"
            :error="errors.inspector_mechanic"
          />
          <BaseInput
            v-model="form.current_mileage"
            label="Current mileage (km)"
            type="number"
            min="0"
            step="1"
            :error="errors.current_mileage"
          />
        </div>

        <div>
          <h3 class="mb-3 font-semibold">Last service dates</h3>
          <div class="grid gap-4 sm:grid-cols-2">
            <BaseInput
              v-for="item in DATE_FIELDS"
              :key="item.field"
              v-model="form[item.field]"
              :label="item.label"
              type="date"
              :error="errors[item.field]"
            />
          </div>
        </div>

        <div>
          <h3 class="mb-3 font-semibold">Vehicle condition</h3>
          <div class="grid gap-4 sm:grid-cols-2">
            <BaseSelect
              v-for="item in CONDITION_FIELDS"
              :key="item.field"
              v-model="form[item.field]"
              :label="item.label"
              placeholder="Not rated"
              :options="ratingOptions"
              allow-empty
              :error="errors[item.field]"
            />
          </div>
        </div>

        <BaseTextarea
          v-model="form.other_parts"
          label="Other parts inspected"
          :rows="6"
          :error="errors.other_parts"
        />
        <BaseTextarea v-model="form.remarks" label="Remarks" :rows="6" :error="errors.remarks" />
        <BaseTextarea
          v-model="form.supervisor_recommendation"
          label="Supervisor's recommendation"
          :rows="6"
          :error="errors.supervisor_recommendation"
        />

        <p v-if="formError" class="rounded-card bg-red-50 p-3 text-small font-medium text-red-700">
          {{ formError }}
        </p>
      </div>

      <template #footer>
        <BaseButton variant="outline" @click="closeForm">Cancel</BaseButton>
        <BaseButton :loading="saving" @click="printAssessment">Print</BaseButton>
      </template>
    </BaseModal>
  </BaseCard>
</template>