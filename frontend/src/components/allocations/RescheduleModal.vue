<script setup>
import { reactive, ref, watch } from 'vue'
import api, { errorMessage, validationErrors } from '@/lib/api'
import { formatDate, todayIso } from '@/lib/format'
import { conflictOf } from '@/lib/allocations'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'

// Open when `allocation` is set.
// Administrators change the date directly. Faculty only send a request.
const props = defineProps({
  allocation: { type: Object, default: null },
  isAdmin: { type: Boolean, default: false },
})

const emit = defineEmits(['close', 'saved', 'conflict'])

const form = reactive({ new_date: '', reason: '' })
const errors = ref({})
const formError = ref('')
const saving = ref(false)

// Start with an empty form each time an allocation is picked.
watch(
  () => props.allocation,
  () => {
    form.new_date = ''
    form.reason = ''
    errors.value = {}
    formError.value = ''
  },
)

async function submit() {
  errors.value = {}
  formError.value = ''

  const path = props.isAdmin
    ? `/allocations/${props.allocation.id}/reschedule`
    : `/allocations/${props.allocation.id}/reschedule-requests`

  saving.value = true
  try {
    await api.post(path, { new_date: form.new_date, reason: form.reason.trim() })
    emit(
      'saved',
      props.isAdmin ? 'Trip date reassigned.' : 'Date change request sent to the administrator.',
    )
  } catch (error) {
    // The vehicle or driver is already booked on the new date.
    const conflict = conflictOf(error)
    if (conflict) {
      emit('conflict', conflict)
      return
    }

    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      formError.value = errorMessage(error, 'Unable to save the date change.')
    }
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <BaseModal :open="Boolean(allocation)" :title="isAdmin ? 'Reassign date' : 'Request date change'"
    :subtitle="allocation ? `${allocation.trip?.destination ?? '—'} · now ${formatDate(allocation.trip?.trip_date)}` : ''"
    @close="emit('close')">
    <div class="flex flex-col gap-4">
      <BaseInput v-model="form.new_date" label="New date" type="date" :min="todayIso()" :error="errors.new_date"
        required />

      <BaseTextarea v-model="form.reason" label="Reason" placeholder="Why does the date need to change?"
        :error="errors.reason" required />

      <p v-if="!isAdmin" class="text-small text-ink-muted">
        The administrator will review your request. The trip date changes only after the
        administrator approves it.
      </p>

      <p v-if="formError" class="rounded-card bg-red-50 p-3 text-small font-medium text-red-700">
        {{ formError }}
      </p>
    </div>

    <template #footer>
      <BaseButton variant="outline" @click="emit('close')">Close</BaseButton>
      <BaseButton :loading="saving" @click="submit">
        {{ isAdmin ? 'Reassign date' : 'Send request' }}
      </BaseButton>
    </template>
  </BaseModal>
</template>