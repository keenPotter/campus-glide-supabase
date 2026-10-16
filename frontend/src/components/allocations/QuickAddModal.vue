<script setup>
import { reactive, ref, watch } from 'vue'
import api, { errorMessage, unwrap, validationErrors } from '@/lib/api'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseModal from '@/components/ui/BaseModal.vue'

// Adds a new driver or vehicle from the allocation window.
// Open when `kind` is 'driver' or 'vehicle'. Sends `created` with the new dropdown item.
const props = defineProps({
  kind: { type: String, default: '' },
})

const emit = defineEmits(['close', 'created'])

function emptyForm() {
  return {
    name: '',
    contact_number: '',
    license_number: '',
    license_expiry_date: '',
    plate_number: '',
    vehicle_model: '',
    capacity: '',
  }
}

const form = reactive(emptyForm())
const errors = ref({})
const formError = ref('')
const saving = ref(false)

// Start with an empty form each time the window opens.
watch(
  () => props.kind,
  () => {
    Object.assign(form, emptyForm())
    errors.value = {}
    formError.value = ''
  },
)

async function save() {
  errors.value = {}
  formError.value = ''

  const isDriver = props.kind === 'driver'
  const body = isDriver
    ? {
        name: form.name.trim(),
        contact_number: form.contact_number.trim(),
        license_number: form.license_number.trim(),
        license_expiry_date: form.license_expiry_date,
      }
    : {
        plate_number: form.plate_number.trim(),
        vehicle_model: form.vehicle_model.trim(),
        capacity: form.capacity ? Number(form.capacity) : undefined,
      }

  saving.value = true
  try {
    const response = await api.post(isDriver ? '/allocation-drivers' : '/allocation-vehicles', body)
    emit('created', { kind: props.kind, item: unwrap(response) })
  } catch (error) {
    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      formError.value = errorMessage(error, 'Unable to save.')
    }
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <BaseModal
    :open="Boolean(kind)"
    :title="kind === 'driver' ? 'Add new driver' : 'Add new vehicle'"
    @close="emit('close')"
  >
    <div v-if="kind === 'driver'" class="flex flex-col gap-4">
      <BaseInput v-model="form.name" label="Full name" :error="errors.name" required />
      <BaseInput
        v-model="form.contact_number"
        label="Contact number"
        type="tel"
        placeholder="0917-123-4567"
        :error="errors.contact_number"
        required
      />
      <BaseInput
        v-model="form.license_number"
        label="License number"
        :error="errors.license_number"
        required
      />
      <BaseInput
        v-model="form.license_expiry_date"
        label="License expiry date"
        type="date"
        :error="errors.license_expiry_date"
        required
      />
    </div>

    <div v-else class="flex flex-col gap-4">
      <BaseInput
        v-model="form.plate_number"
        label="Plate number"
        :error="errors.plate_number"
        required
      />
      <BaseInput
        v-model="form.vehicle_model"
        label="Vehicle model"
        placeholder="Toyota HiAce"
        :error="errors.vehicle_model"
        required
      />
      <BaseInput
        v-model="form.capacity"
        label="Seating capacity (optional)"
        type="number"
        min="1"
        :error="errors.capacity"
      />
    </div>

    <p v-if="formError" class="mt-4 rounded-card bg-red-50 p-3 text-small font-medium text-red-700">
      {{ formError }}
    </p>

    <template #footer>
      <BaseButton variant="outline" @click="emit('close')">Cancel</BaseButton>
      <BaseButton :loading="saving" @click="save">Add</BaseButton>
    </template>
  </BaseModal>
</template>