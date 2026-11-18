<script setup>
import { reactive, ref, watch } from 'vue'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import { errorMessage, validationErrors } from '@/lib/api'
import { todayIso } from '@/lib/format'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import VehicleRequestFields from '@/components/requests/VehicleRequestFields.vue'

const props = defineProps({
  open: { type: Boolean, default: false },
})

const emit = defineEmits(['close', 'submitted'])
const store = useVehicleRequestStore()
const toast = useToast()
const submitting = ref(false)
const errors = ref({})

function emptyForm() {
  const today = todayIso()
  return {
    destination: '',
    purpose: '',
    trip_date: today,
    trip_end_date: today,
    min_trip_date: today,
    trip_type: '',
    departure_time: '07:30',
    estimated_return_time: '17:00',
    passengers: '',
    number_of_passengers: 1,
  }
}

const form = reactive(emptyForm())

watch(
  () => props.open,
  (open) => {
    if (!open) return
    Object.assign(form, emptyForm())
    errors.value = {}
  },
)

async function submit() {
  if (submitting.value) return

  submitting.value = true
  errors.value = {}

  try {
    const payload = {
      ...form,
      number_of_passengers: Number(form.number_of_passengers),
    }
    delete payload.min_trip_date

    const created = await store.create(payload)
    toast.success('Request submitted for approval.')
    emit('submitted', created)
  } catch (error) {
    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      toast.error(errorMessage(error, 'Unable to submit your request.'))
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <BaseModal
    :open="open"
    title="Request for use of vehicle"
    subtitle="Please submit this form at least three days before travel."
    @close="emit('close')"
  >
    <form class="flex flex-col gap-5" @submit.prevent="submit">
      <VehicleRequestFields :form="form" :errors="errors" />

      <div class="flex justify-end gap-2">
        <BaseButton variant="outline" :disabled="submitting" @click="emit('close')">
          Cancel
        </BaseButton>
        <BaseButton type="submit" :loading="submitting">Submit request</BaseButton>
      </div>
    </form>
  </BaseModal>
</template>
