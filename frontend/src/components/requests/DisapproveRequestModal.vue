<script setup>
import { ref, watch } from 'vue'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import { errorMessage, validationErrors } from '@/lib/api'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'

// Shared by the request list and the request detail page.
// The modal is open when `request` is set. `done` is sent after a successful disapproval.
const props = defineProps({
  request: { type: Object, default: null },
})

const emit = defineEmits(['close', 'done'])

const store = useVehicleRequestStore()
const toast = useToast()

const reason = ref('')
const error = ref('')
const submitting = ref(false)

// Start with an empty form each time a request is picked.
watch(
  () => props.request,
  () => {
    reason.value = ''
    error.value = ''
  },
)

async function confirm() {
  submitting.value = true
  error.value = ''

  try {
    await store.updateStatus(props.request.id, {
      status: 'disapproved',
      remarks: reason.value,
    })
    toast.success(`Request #${props.request.id} disapproved.`)
    emit('done')
  } catch (e) {
    error.value = validationErrors(e).remarks ?? errorMessage(e)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <BaseModal
    :open="Boolean(request)"
    title="Disapprove request"
    :subtitle="request ? `Request #${request.id} — ${request.destination}` : ''"
    @close="emit('close')"
  >
    <BaseTextarea
      v-model="reason"
      label="Reason for disapproval"
      placeholder="e.g. Vehicle already assigned for that date."
      :error="error"
      required
    />

    <template #footer>
      <BaseButton variant="outline" @click="emit('close')">Cancel</BaseButton>
      <BaseButton variant="danger" :loading="submitting" @click="confirm">
        Disapprove request
      </BaseButton>
    </template>
  </BaseModal>
</template>