<script setup>
import { computed, reactive, ref, watch } from 'vue'
import api, { errorMessage, unwrap, validationErrors } from '@/lib/api'
import { formatDateRange, formatTime } from '@/lib/format'
import { availabilityOptions, conflictOf, passengerText } from '@/lib/allocations'
import { useNotificationStore } from '@/stores/notifications'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'
import ConflictModal from '@/components/allocations/ConflictModal.vue'

// Approves a pending vehicle request and assigns its vehicle and driver in one step.
// The modal is open when `request` is set. `done` is sent after it was saved.
// The request is approved only when the administrator saves.
// If the window is closed without saving, the request stays pending.
// Vehicles and drivers that are not available on the trip dates cannot be picked.
const props = defineProps({
  request: { type: Object, default: null },
})

const emit = defineEmits(['close', 'done'])

const notifications = useNotificationStore()

const form = reactive({ vehicle_id: '', driver_id: '', notes: '' })
const errors = ref({})
const formError = ref('')
const saving = ref(false)
const loadingOptions = ref(false)
const vehicleItems = ref([])
const driverItems = ref([])
const conflicts = ref([])

const vehicleOptions = computed(() => availabilityOptions(vehicleItems.value))
const driverOptions = computed(() => availabilityOptions(driverItems.value))

function placeholderFor(items, noun) {
  if (loadingOptions.value) return 'Checking availability...'
  if (items.length && items.every((item) => item.available === false)) {
    return `No ${noun} is available on these dates`
  }
  return `Select ${noun}`
}

const vehiclePlaceholder = computed(() => placeholderFor(vehicleItems.value, 'vehicle'))
const driverPlaceholder = computed(() => placeholderFor(driverItems.value, 'driver'))

// Load the vehicles and drivers for the dates of this request.
async function loadOptions() {
  const request = props.request
  if (!request) return

  loadingOptions.value = true
  try {
    const data = unwrap(
      await api.get('/allocation-options', {
        params: {
          start_date: request.trip_date,
          end_date: request.trip_end_date || request.trip_date,
        },
      }),
    )
    vehicleItems.value = data.vehicles
    driverItems.value = data.drivers
  } catch (error) {
    formError.value = errorMessage(error, 'Unable to load vehicles and drivers.')
  } finally {
    loadingOptions.value = false
  }
}

// Start with an empty form each time a request is picked.
watch(
  () => props.request,
  (request) => {
    Object.assign(form, { vehicle_id: '', driver_id: '', notes: '' })
    errors.value = {}
    formError.value = ''
    conflicts.value = []
    vehicleItems.value = []
    driverItems.value = []

    if (request) loadOptions()
  },
)

async function save() {
  errors.value = {}
  formError.value = ''

  const problems = {}
  if (!form.vehicle_id) problems.vehicle_id = 'Please select a vehicle.'
  if (!form.driver_id) problems.driver_id = 'Please select a driver.'

  if (Object.keys(problems).length) {
    errors.value = problems
    return
  }

  saving.value = true
  try {
    await api.post('/allocations', {
      vehicle_request_id: props.request.id,
      vehicle_id: Number(form.vehicle_id),
      driver_id: Number(form.driver_id),
      notes: form.notes || null,
      // The backend approves the request and saves the assignment together.
      approve_request: true,
    })
    notifications.refresh()
    emit('done')
  } catch (error) {
    // The vehicle, the driver or both were booked by someone else in the meantime.
    const found = conflictOf(error)
    if (found) {
      conflicts.value = found
      return
    }

    errors.value = validationErrors(error)
    formError.value =
      errors.value.vehicle_request_id ??
      (Object.keys(errors.value).length ? '' : errorMessage(error, 'Unable to approve and assign this request.'))
  } finally {
    saving.value = false
  }
}

// After a conflict, clear the choices that caused it and load the lists again.
function closeConflict() {
  if (conflicts.value.some((item) => item.type === 'driver')) form.driver_id = ''
  if (conflicts.value.some((item) => item.type === 'vehicle')) form.vehicle_id = ''
  conflicts.value = []
  loadOptions()
}
</script>

<template>
  <BaseModal
    :open="Boolean(request)"
    title="Approve and assign"
    :subtitle="request ? `Request #${request.id} — ${request.destination}` : ''"
    @close="emit('close')"
  >
    <div v-if="request" class="flex flex-col gap-4">
      <div class="rounded-card bg-surface p-3 text-small">
        <p class="font-medium text-ink">{{ formatDateRange(request.trip_date, request.trip_end_date) }}</p>
        <p class="mt-1 text-ink-muted">
          Departure {{ formatTime(request.departure_time) }} ·
          {{ passengerText(request.number_of_passengers) }}
        </p>
      </div>

      <p class="rounded-card border-l-4 border-secondary bg-secondary-50 p-3 text-small text-secondary-700">
        The request is approved only after you save. If you close this window, it stays pending.
      </p>

      <BaseSelect
        v-model="form.vehicle_id"
        label="Vehicle"
        :options="vehicleOptions"
        :placeholder="vehiclePlaceholder"
        :error="errors.vehicle_id"
        required
      />

      <BaseSelect
        v-model="form.driver_id"
        label="Driver"
        :options="driverOptions"
        :placeholder="driverPlaceholder"
        :error="errors.driver_id"
        required
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
      <BaseButton :loading="saving" :disabled="loadingOptions" @click="save">
        Approve and assign
      </BaseButton>
    </template>
  </BaseModal>

  <ConflictModal :conflicts="conflicts" @close="closeConflict" />
</template>