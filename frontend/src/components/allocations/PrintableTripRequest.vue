<script setup>
import { computed, ref, watch } from 'vue'
import api, { errorMessage, unwrap } from '@/lib/api'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'

// Shows the printable "Request for Use of Vehicle" form and can send it to another administrator.
// The form itself is built by the backend (AllocationPrintController), so there is only one copy of it.
// Open when `allocation` is set. Administrators only.
const props = defineProps({
  allocation: { type: Object, default: null },
  notice: { type: String, default: '' },
  admins: { type: Array, default: () => [] },
})

const emit = defineEmits(['close', 'sent'])

const FALLBACK_ERROR = 'Unable to load the trip request.'

const html = ref('')
const loading = ref(false)
const loadError = ref('')
const message = ref('')
const frame = ref(null)

const shareOpen = ref(false)
const recipientId = ref('')
const sending = ref(false)
const sendError = ref('')

const adminOptions = computed(() =>
  props.admins.map((admin) => ({ value: admin.id, label: `${admin.name} · ${admin.email}` })),
)

// The form comes back as HTML text, so an error comes back as text too. Read the message from it.
function readError(error) {
  const body = error?.response?.data

  if (typeof body === 'string') {
    try {
      return JSON.parse(body).message ?? FALLBACK_ERROR
    } catch {
      return FALLBACK_ERROR
    }
  }

  return errorMessage(error, FALLBACK_ERROR)
}

watch(
  () => props.allocation,
  async (allocation) => {
    html.value = ''
    loadError.value = ''
    sendError.value = ''
    shareOpen.value = false
    recipientId.value = ''
    message.value = props.notice

    if (!allocation) return

    loading.value = true
    try {
      const { data } = await api.get(`/allocations/${allocation.id}/print`, {
        responseType: 'text',
        headers: { Accept: 'text/html' },
      })
      html.value = data
    } catch (error) {
      loadError.value = readError(error)
    } finally {
      loading.value = false
    }
  },
)

// Only the form inside the frame is printed, not the rest of the app.
function printNow() {
  const win = frame.value?.contentWindow
  win?.focus()
  win?.print()
}

async function send() {
  if (!recipientId.value || sending.value) return

  sending.value = true
  sendError.value = ''
  try {
    const share = unwrap(
      await api.post('/trip-request-shares', {
        allocation_id: props.allocation.id,
        recipient_id: Number(recipientId.value),
      }),
    )
    message.value = `Trip request sent to ${share.recipient.name}.`
    shareOpen.value = false
    recipientId.value = ''
    emit('sent')
  } catch (error) {
    sendError.value = errorMessage(error, 'Unable to send the trip request.')
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="allocation"
      class="fixed inset-0 z-[55] flex items-start justify-center overflow-y-auto bg-ink/40 p-0 sm:p-page"
    >
      <div class="w-full max-w-4xl bg-surface p-card shadow-pop sm:rounded-card">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <h2 class="text-section-title">Trip request</h2>
          <div class="flex flex-wrap gap-2">
            <BaseButton v-if="html" variant="outline" size="sm" @click="shareOpen = !shareOpen">
              Send to admin
            </BaseButton>
            <BaseButton size="sm" :disabled="!html" @click="printNow">Print / Save as PDF</BaseButton>
            <BaseButton variant="outline" size="sm" @click="emit('close')">Close</BaseButton>
          </div>
        </div>

        <div
          v-if="shareOpen"
          class="mt-3 flex flex-col gap-3 rounded-card border border-line bg-white p-card"
        >
          <template v-if="admins.length">
            <BaseSelect
              v-model="recipientId"
              label="Send this trip request to"
              :options="adminOptions"
              placeholder="Select an administrator"
              :disabled="sending"
            />
            <div class="flex justify-end">
              <BaseButton size="sm" :disabled="!recipientId" :loading="sending" @click="send">
                Send request
              </BaseButton>
            </div>
          </template>
          <p v-else class="text-small text-ink-muted">
            No other administrator accounts are available to receive this request.
          </p>
        </div>

        <p v-if="sendError" class="mt-3 text-small text-red-700">{{ sendError }}</p>
        <p
          v-if="message"
          class="mt-3 rounded-card border border-secondary-200 bg-secondary-50 p-3 text-small text-secondary-700"
        >
          {{ message }}
        </p>

        <p v-if="loading" class="mt-3 text-small text-ink-muted">Loading...</p>
        <p v-else-if="loadError" class="mt-3 text-small text-red-700">{{ loadError }}</p>

        <iframe
          v-if="html"
          ref="frame"
          :srcdoc="html"
          title="Request for use of vehicle"
          class="mt-3 h-[70vh] w-full rounded-card border border-line bg-white"
        />
      </div>
    </div>
  </Teleport>
</template>