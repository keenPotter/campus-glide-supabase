<script setup>
import { computed, reactive, ref, watch } from 'vue'
import api, { errorMessage, unwrap, validationErrors } from '@/lib/api'
import { todayIso } from '@/lib/format'
import { availabilityOptions, conflictOf, shiftedRange } from '@/lib/allocations'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'
import ConflictModal from '@/components/allocations/ConflictModal.vue'

// Reassigns an existing allocation: vehicle, driver, date and status.
// New allocations are made when a vehicle request is approved (see ApproveAssignModal).
// The window shows the vehicle, driver and date with their current values,
// so the administrator changes only what is needed.
// A reason is required only when the date is changed. The date is locked unless the trip is scheduled.
// The vehicle and driver lists come from the backend and are checked for the trip dates.
// When the date changes, the lists are loaded again for the new dates.
const props = defineProps({
  open: { type: Boolean, default: false },
  allocation: { type: Object, default: null },
})

const emit = defineEmits(['close', 'saved'])

const statusOptions = [
  { value: 'scheduled', label: 'Scheduled' },
  { value: 'in_progress', label: 'In progress' },
  { value: 'completed', label: 'Completed' },
]

const form = reactive({
  vehicle_id: '',
  driver_id: '',
  trip_date: '',
  reason: '',
  status: '',
  notes: '',
})
const errors = ref({})
const formError = ref('')
const saving = ref(false)
const loadingOptions = ref(false)
const vehicleItems = ref([])
const driverItems = ref([])
// Every conflict found on the last save (vehicle and driver together).
const conflicts = ref([])

const title = computed(() =>
  props.allocation ? `Reassign allocation #${props.allocation.id}` : 'Reassign allocation',
)

// Only a scheduled trip can be moved to another date.
const dateLocked = computed(() => props.allocation?.status !== 'scheduled')

const currentDate = computed(() => props.allocation?.trip?.trip_date ?? '')

const dateChanged = computed(
  () => Boolean(props.allocation) && !dateLocked.value && Boolean(form.trip_date) && form.trip_date !== currentDate.value,
)

const requestOptions = computed(() => {
  const vehicleRequest = props.allocation?.vehicle_request
  if (!vehicleRequest) return []

  return [
    {
      value: vehicleRequest.id,
      label: `#${vehicleRequest.id} · ${props.allocation.trip?.destination ?? ''}`,
    },
  ]
})

// The current vehicle or driver is always in the list.
const vehicleOptions = computed(() => {
  const options = availabilityOptions(vehicleItems.value)
  const current = props.allocation?.vehicle

  if (current?.id && !options.some((item) => item.value === current.id)) {
    options.unshift({ value: current.id, label: `${current.plate_number} — ${current.vehicle_model}` })
  }

  return options
})

const driverOptions = computed(() => {
  const options = availabilityOptions(driverItems.value)
  const current = props.allocation?.driver

  if (current?.id && !options.some((item) => item.value === current.id)) {
    options.unshift({ value: current.id, label: current.name })
  }

  return options
})

const conflictHint = computed(() =>
  dateChanged.value ? 'Please choose another date, vehicle or driver.' : '',
)

// Loads the vehicles and drivers with their availability for the trip dates.
// This trip is ignored, so it does not block its own vehicle and driver.
async function loadOptions() {
  const current = props.allocation
  if (!current?.trip?.id) return

  const start = form.trip_date || current.trip.trip_date
  const range = shiftedRange(current.trip.trip_date, current.trip.trip_end_date, start)

  loadingOptions.value = true
  try {
    const data = unwrap(
      await api.get('/allocation-options', {
        params: { start_date: range.start, end_date: range.end, ignore_trip_id: current.trip.id },
      }),
    )
    vehicleItems.value = data.vehicles
    driverItems.value = data.drivers

    // A choice that is no longer available on the new dates is cleared.
    const blocked = (items, id) => items.some((item) => String(item.id) === String(id) && item.available === false)
    if (blocked(vehicleItems.value, form.vehicle_id)) form.vehicle_id = ''
    if (blocked(driverItems.value, form.driver_id)) form.driver_id = ''
  } catch (error) {
    formError.value = errorMessage(error, 'Unable to load vehicles and drivers.')
  } finally {
    loadingOptions.value = false
  }
}

// Start fresh each time the window opens.
watch(
  () => props.open,
  (open) => {
    if (!open) return

    errors.value = {}
    formError.value = ''
    conflicts.value = []
    vehicleItems.value = []
    driverItems.value = []

    const current = props.allocation
    Object.assign(form, {
      vehicle_id: current?.vehicle?.id ?? '',
      driver_id: current?.driver?.id ?? '',
      trip_date: current?.trip?.trip_date ?? '',
      reason: '',
      status: current?.status ?? '',
      notes: current?.notes ?? '',
    })

    loadOptions()
  },
)

// Check the vehicles and drivers again when another date is picked.
watch(
  () => form.trip_date,
  (value, previous) => {
    if (props.open && value && previous && !dateLocked.value) loadOptions()
  },
)

async function save() {
  if (!props.allocation) return

  errors.value = {}
  formError.value = ''

  const vehicleId = Number(form.vehicle_id) || null
  const driverId = Number(form.driver_id) || null

  const problems = {}
  if (!vehicleId) problems.vehicle_id = 'Please select a vehicle.'
  if (!driverId) problems.driver_id = 'Please select a driver.'
  if (dateChanged.value && !form.reason.trim()) problems.reason = 'Please give a reason for changing the date.'

  if (Object.keys(problems).length) {
    errors.value = problems
    return
  }

  saving.value = true
  try {
    await api.put(`/allocations/${props.allocation.id}`, {
      vehicle_id: vehicleId,
      driver_id: driverId,
      status: form.status || undefined,
      notes: form.notes || null,
      // The date and the reason are sent only when the date was changed.
      new_date: dateChanged.value ? form.trip_date : undefined,
      reason: dateChanged.value ? form.reason.trim() : undefined,
    })
    emit('saved')
  } catch (error) {
    // The vehicle, the driver or both are already booked on those dates.
    const found = conflictOf(error)
    if (found) {
      conflicts.value = found
      return
    }

    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      formError.value = errorMessage(error, 'Unable to save this allocation.')
    }
  } finally {
    saving.value = false
  }
}

// After a conflict, clear every choice that caused it so a new one is picked.
// When the date was changed, nothing is cleared, because the date may be the cause.
function closeConflict() {
  if (!dateChanged.value) {
    if (conflicts.value.some((item) => item.type === 'driver')) form.driver_id = ''
    if (conflicts.value.some((item) => item.type === 'vehicle')) form.vehicle_id = ''
  }
  conflicts.value = []
  loadOptions()
}
</script>

<template>
  <BaseModal :open="open" :title="title" @close="emit('close')">
    <div class="flex flex-col gap-4">
      <BaseSelect
        :model-value="allocation?.vehicle_request?.id ?? ''"
        label="Approved vehicle request"
        :options="requestOptions"
        disabled
      />

      <BaseSelect
        v-model="form.vehicle_id"
        label="Vehicle"
        :options="vehicleOptions"
        :placeholder="loadingOptions ? 'Checking availability...' : 'Select vehicle'"
        :error="errors.vehicle_id"
        required
      />

      <BaseSelect
        v-model="form.driver_id"
        label="Driver"
        :options="driverOptions"
        :placeholder="loadingOptions ? 'Checking availability...' : 'Select driver'"
        :error="errors.driver_id"
        required
      />

      <BaseInput
        v-model="form.trip_date"
        label="Trip date"
        type="date"
        :min="todayIso()"
        :disabled="dateLocked"
        :hint="dateLocked ? 'The date is locked. Only scheduled trips can be moved to another date.' : ''"
        :error="errors.new_date"
      />

      <BaseTextarea
        v-if="dateChanged"
        v-model="form.reason"
        label="Reason for changing the date"
        placeholder="Why does the date need to change?"
        :error="errors.reason"
        required
      />

      <BaseSelect
        v-model="form.status"
        label="Trip status"
        :options="statusOptions"
        placeholder="Unchanged"
        allow-empty
        :error="errors.status"
      />

      <BaseTextarea
        v-model="form.notes"
        label="Notes"
        placeholder="Notes (optional)"
        :error="errors.notes"
      />

      <p v-if="formError" class="rounded-card bg-red-50 p-3 text-small font-medium text-red-700">
        {{ formError }}
      </p>
    </div>

    <template #footer>
      <BaseButton variant="outline" @click="emit('close')">Cancel</BaseButton>
      <BaseButton :loading="saving" :disabled="loadingOptions" @click="save">Save</BaseButton>
    </template>
  </BaseModal>

  <ConflictModal :conflicts="conflicts" :hint="conflictHint" @close="closeConflict" />
</template>