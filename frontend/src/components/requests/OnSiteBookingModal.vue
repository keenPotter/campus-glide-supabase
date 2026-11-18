<script setup>
import { computed, reactive, ref, watch } from 'vue'
import api, { errorMessage, unwrap, validationErrors } from '@/lib/api'
import { availabilityOptions, conflictOf } from '@/lib/allocations'
import { todayIso, TRIP_TYPE_DESCRIPTIONS } from '@/lib/format'
import { useNotificationStore } from '@/stores/notifications'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'
import ConflictModal from '@/components/allocations/ConflictModal.vue'

const props = defineProps({
  open: { type: Boolean, default: false },
})

const emit = defineEmits(['close', 'submitted'])

const notifications = useNotificationStore()
const tripTypeOptions = [
  { value: 'inclusive', label: TRIP_TYPE_DESCRIPTIONS.inclusive },
  { value: 'exclusive', label: TRIP_TYPE_DESCRIPTIONS.exclusive },
]
const form = reactive(createForm())
const errors = ref({})
const formError = ref('')
const saving = ref(false)
const loadingOptions = ref(false)
const optionsError = ref('')
const vehicleItems = ref([])
const driverItems = ref([])
const conflicts = ref([])
let optionsSequence = 0

const vehicleOptions = computed(() => availabilityOptions(vehicleItems.value))
const driverOptions = computed(() => availabilityOptions(driverItems.value))
const scheduleReady = computed(() =>
  Boolean(
    form.trip_date
    && form.trip_end_date
    && form.trip_end_date >= form.trip_date
    && form.departure_time
    && form.estimated_return_time
    && form.estimated_return_time > form.departure_time,
  ),
)
const assignmentError = computed(() => errors.value.assignment || errors.value.vehicle_id || errors.value.driver_id)

function createForm() {
  return {
    requester_name: '',
    requester_department: '',
    requester_contact: '',
    destination: '',
    purpose: '',
    trip_date: '',
    trip_end_date: '',
    trip_type: '',
    departure_time: '',
    estimated_return_time: '',
    passengers: '',
    number_of_passengers: '',
    vehicle_id: '',
    driver_id: '',
  }
}

function resetForm() {
  Object.assign(form, createForm())
  errors.value = {}
  formError.value = ''
  optionsError.value = ''
  vehicleItems.value = []
  driverItems.value = []
  conflicts.value = []
}

watch(
  () => props.open,
  (open) => {
    optionsSequence += 1
    loadingOptions.value = false
    resetForm()
    if (!open) return
  },
)

watch(
  () => [
    form.trip_date,
    form.trip_end_date,
    form.departure_time,
    form.estimated_return_time,
  ],
  async () => {
    form.vehicle_id = ''
    form.driver_id = ''
    vehicleItems.value = []
    driverItems.value = []
    optionsError.value = ''

    await loadOptions()
  },
)

async function loadOptions() {
  const sequence = ++optionsSequence
  if (!props.open || !scheduleReady.value) {
    loadingOptions.value = false
    return
  }

  loadingOptions.value = true
  try {
    const data = unwrap(
      await api.get('/allocation-options', {
        params: {
          start_date: form.trip_date,
          end_date: form.trip_end_date,
          start_time: form.departure_time,
          end_time: form.estimated_return_time,
        },
      }),
    )
    if (sequence === optionsSequence) {
      vehicleItems.value = data.vehicles
      driverItems.value = data.drivers
    }
  } catch (error) {
    if (sequence === optionsSequence) {
      optionsError.value = errorMessage(error, 'Unable to load vehicle and driver availability.')
    }
  } finally {
    if (sequence === optionsSequence) loadingOptions.value = false
  }
}

async function save() {
  errors.value = {}
  formError.value = ''

  const problems = {}
  for (const field of [
    'requester_name',
    'requester_department',
    'requester_contact',
    'destination',
    'purpose',
    'trip_date',
    'trip_end_date',
    'trip_type',
    'departure_time',
    'estimated_return_time',
    'passengers',
    'number_of_passengers',
  ]) {
    if (!String(form[field] ?? '').trim()) problems[field] = 'This field is required.'
  }

  if (form.trip_date && form.trip_date < todayIso()) {
    problems.trip_date = 'Departure date cannot be in the past.'
  }
  if (form.trip_date && form.trip_end_date && form.trip_end_date < form.trip_date) {
    problems.trip_end_date = 'Return date must be on or after the departure date.'
  }
  if (form.departure_time && form.estimated_return_time && form.estimated_return_time <= form.departure_time) {
    problems.estimated_return_time = 'Return time must be after departure time.'
  }
  if (form.number_of_passengers && Number(form.number_of_passengers) < 1) {
    problems.number_of_passengers = 'At least one passenger is required.'
  }
  if (Boolean(form.vehicle_id) !== Boolean(form.driver_id)) {
    problems.assignment = 'Select both a vehicle and a driver, or leave both unassigned.'
  }

  if (Object.keys(problems).length) {
    errors.value = problems
    return
  }

  saving.value = true
  try {
    const response = await api.post('/vehicle-requests/on-site', {
      ...form,
      number_of_passengers: Number(form.number_of_passengers),
      vehicle_id: form.vehicle_id ? Number(form.vehicle_id) : null,
      driver_id: form.driver_id ? Number(form.driver_id) : null,
    })
    notifications.refresh()
    emit('submitted', unwrap(response))
  } catch (error) {
    const found = conflictOf(error)
    if (found) {
      conflicts.value = found
      return
    }

    errors.value = validationErrors(error)
    formError.value = Object.keys(errors.value).length
      ? ''
      : errorMessage(error, 'Unable to record this on-site trip request.')
  } finally {
    saving.value = false
  }
}

function closeConflict() {
  if (conflicts.value.some((item) => item.type === 'vehicle')) form.vehicle_id = ''
  if (conflicts.value.some((item) => item.type === 'driver')) form.driver_id = ''
  conflicts.value = []
  loadOptions()
}
</script>

<template>
  <BaseModal
    :open="open"
    title="Record On-Site Trip Request"
    subtitle="Enter the requesting personnel and trip details."
    @close="emit('close')"
  >
    <div class="flex flex-col gap-5">
      <section class="flex flex-col gap-3">
        <h3 class="font-semibold text-ink">Requesting Personnel</h3>
        <BaseInput
          id="on-site-requester-name"
          v-model="form.requester_name"
          label="Full Name"
          :error="errors.requester_name"
          required
        />
        <BaseInput
          id="on-site-requester-department"
          v-model="form.requester_department"
          label="Office/Department"
          :error="errors.requester_department"
          required
        />
        <BaseInput
          id="on-site-requester-contact"
          v-model="form.requester_contact"
          label="Contact Number"
          :error="errors.requester_contact"
          required
        />
      </section>

      <section class="flex flex-col gap-3">
        <h3 class="font-semibold text-ink">Trip Details</h3>
        <BaseInput
          id="on-site-destination"
          v-model="form.destination"
          label="Destination"
          :error="errors.destination"
          required
        />
        <BaseTextarea
          v-model="form.purpose"
          label="Purpose"
          placeholder="Purpose of the trip"
          :error="errors.purpose"
          required
        />
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <BaseInput
            id="on-site-trip-date"
            v-model="form.trip_date"
            type="date"
            label="Departure Date"
            :min="todayIso()"
            :error="errors.trip_date"
            required
          />
          <BaseInput
            id="on-site-trip-end-date"
            v-model="form.trip_end_date"
            type="date"
            label="Expected Return Date"
            :min="form.trip_date || todayIso()"
            :error="errors.trip_end_date"
            required
          />
          <BaseInput
            id="on-site-departure-time"
            v-model="form.departure_time"
            type="time"
            label="Departure Time"
            :error="errors.departure_time"
            required
          />
          <BaseInput
            id="on-site-return-time"
            v-model="form.estimated_return_time"
            type="time"
            label="Expected Return Time"
            :error="errors.estimated_return_time"
            required
          />
          <BaseSelect
            v-model="form.trip_type"
            label="Trip type"
            :options="tripTypeOptions"
            placeholder="Select trip type"
            :error="errors.trip_type"
            required
          />
          <BaseInput
            id="on-site-passenger-count"
            v-model="form.number_of_passengers"
            type="number"
            min="1"
            step="1"
            label="Number of Passengers"
            :error="errors.number_of_passengers"
            required
          />
        </div>
        <BaseInput
          id="on-site-passengers"
          v-model="form.passengers"
          label="Authorized Passengers"
          hint="Enter the passenger names or group description."
          :error="errors.passengers"
          required
        />
      </section>

      <section class="flex flex-col gap-3">
        <div>
          <h3 class="font-semibold text-ink">Optional Immediate Assignment</h3>
          <p class="mt-1 text-small text-ink-muted">
            Leave both unselected to keep this request in the allocation queue.
          </p>
        </div>
        <p v-if="loadingOptions" class="text-small text-ink-muted">Checking availability for this schedule…</p>
        <p v-else-if="optionsError" class="rounded-card bg-amber-50 p-3 text-small text-amber-800">
          {{ optionsError }} You can still save without assigning a vehicle or driver.
        </p>
        <p
          v-if="assignmentError"
          class="text-small text-red-600"
        >
          {{ assignmentError }}
        </p>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <BaseSelect
            v-model="form.vehicle_id"
            label="Available Vehicle"
            :options="vehicleOptions"
            :placeholder="scheduleReady ? 'Leave unassigned' : 'Enter a valid schedule first'"
            :disabled="!scheduleReady || loadingOptions || Boolean(optionsError)"
            :error="errors.vehicle_id"
            allow-empty
          />
          <BaseSelect
            v-model="form.driver_id"
            label="Available Driver"
            :options="driverOptions"
            :placeholder="scheduleReady ? 'Leave unassigned' : 'Enter a valid schedule first'"
            :disabled="!scheduleReady || loadingOptions || Boolean(optionsError)"
            :error="errors.driver_id"
            allow-empty
          />
        </div>
        <p v-if="!scheduleReady" class="text-small text-ink-muted">
          Enter valid dates and times to see vehicles and drivers available for the trip.
        </p>
        <p v-if="formError" class="rounded-card bg-red-50 p-3 text-small font-medium text-red-700">
          {{ formError }}
        </p>
      </section>
    </div>

    <template #footer>
      <BaseButton variant="outline" @click="emit('close')">Cancel</BaseButton>
      <BaseButton :loading="saving" @click="save">Record Request</BaseButton>
    </template>
  </BaseModal>

  <ConflictModal :conflicts="conflicts" @close="closeConflict" />
</template>
