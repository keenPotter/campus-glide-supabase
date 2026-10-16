<script setup>
import { computed, ref, watch } from 'vue'
import api, { errorMessage, validationErrors } from '@/lib/api'
import { formatDate } from '@/lib/format'
import { conflictOf } from '@/lib/allocations'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'

// The administrator approves or disapproves a faculty date change request.
// Open when both `item` and `action` ('approve' or 'disapprove') are set.
// A reason is required to disapprove. A note is optional when approving.
const props = defineProps({
  item: { type: Object, default: null },
  action: { type: String, default: '' },
})

const emit = defineEmits(['close', 'saved', 'conflict'])

const note = ref('')
const error = ref('')
const saving = ref(false)

const isApprove = computed(() => props.action === 'approve')

// Start with an empty form each time a request is picked.
watch(
  () => [props.item, props.action],
  () => {
    note.value = ''
    error.value = ''
  },
)

async function submit() {
  error.value = ''

  if (!isApprove.value && !note.value.trim()) {
    error.value = 'Please give a reason for disapproving this request.'
    return
  }

  saving.value = true
  try {
    await api.post(`/reschedule-requests/${props.item.id}/${props.action}`, {
      admin_reason: note.value.trim() || undefined,
    })
    emit(
      'saved',
      isApprove.value
        ? 'Request approved. The trip date was changed.'
        : 'Request disapproved. The faculty member can see your reason.',
    )
  } catch (e) {
    // The vehicle or driver is already booked on the requested date.
    const conflict = conflictOf(e)
    if (conflict) {
      emit('conflict', conflict)
      return
    }

    error.value = validationErrors(e).admin_reason ?? errorMessage(e, 'Unable to save your decision.')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <BaseModal
    :open="Boolean(item && action)"
    :title="isApprove ? 'Approve date change' : 'Disapprove date change'"
    :subtitle="item ? item.trip?.destination ?? '' : ''"
    @close="emit('close')"
  >
    <div v-if="item" class="flex flex-col gap-4">
      <div class="rounded-card bg-surface p-3 text-small">
        <p class="text-ink-muted">
          Requested by {{ item.requested_by ?? '—' }}: {{ formatDate(item.old_date) }} →
          <strong class="text-ink">{{ formatDate(item.new_date) }}</strong>
        </p>
        <p class="mt-1 text-ink-muted">Reason: {{ item.reason }}</p>
      </div>

      <BaseTextarea
        v-model="note"
        :label="isApprove ? 'Note (optional)' : 'Reason for disapproving'"
        :placeholder="isApprove ? 'Add a note for the requester.' : 'Why is the date change not possible?'"
        :error="error"
        :required="!isApprove"
      />
    </div>

    <template #footer>
      <BaseButton variant="outline" @click="emit('close')">Cancel</BaseButton>
      <BaseButton :variant="isApprove ? 'primary' : 'danger'" :loading="saving" @click="submit">
        {{ isApprove ? 'Approve and move trip' : 'Disapprove request' }}
      </BaseButton>
    </template>
  </BaseModal>
</template>