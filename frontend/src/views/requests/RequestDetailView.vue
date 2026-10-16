<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import { errorMessage } from '@/lib/api'
import { formatDate, formatDateTime, formatTime, fullName } from '@/lib/format'
import { useToast } from '@/composables/useToast'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import ApproveAssignModal from '@/components/requests/ApproveAssignModal.vue'
import DisapproveRequestModal from '@/components/requests/DisapproveRequestModal.vue'

const auth = useAuthStore()
const store = useVehicleRequestStore()
const route = useRoute()
const router = useRouter()
const toast = useToast()

const request = ref(null)
const loading = ref(true)
const approveOpen = ref(false)
const disapproveOpen = ref(false)

const canEdit = computed(
  () => auth.isFaculty && ['pending', 'approved'].includes(request.value?.status),
)

const rows = computed(() => {
  if (!request.value) return []
  const value = request.value

  return [
    { label: 'Requesting official', value: fullName(value.requested_by) },
    { label: 'Destination', value: value.destination },
    { label: 'Purpose', value: value.purpose },
    { label: 'Date of travel', value: formatDate(value.trip_date) },
    { label: 'End of travel', value: formatDate(value.trip_end_date) },
    { label: 'Days of travel', value: value.travel_days ?? '—' },
    { label: 'Inclusive / Exclusive', value: value.trip_type },
    { label: 'Time of departure', value: formatTime(value.departure_time) },
    { label: 'Estimated return', value: formatTime(value.return_time) },
    { label: 'Authorized passengers', value: value.passengers },
    { label: 'Number of passengers', value: value.number_of_passengers ?? '—' },
    { label: 'Date requested', value: formatDateTime(value.created_at) },
    { label: 'Approved on', value: value.approved_date ? formatDateTime(value.approved_date) : '—' },
  ]
})

onMounted(load)

async function load() {
  loading.value = true
  try {
    request.value = await store.find(route.params.id)
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to load this request.'))
    router.push({ name: 'requests.index' })
  } finally {
    loading.value = false
  }
}

// Approve opens the assign window. The request is approved only after the vehicle and driver are saved.
function onApproved() {
  approveOpen.value = false
  toast.success('Request approved. Vehicle and driver assigned.')
  load()
}

function onDisapproved() {
  disapproveOpen.value = false
  load()
}
</script>

<template>
  <div v-if="loading" class="flex justify-center p-12">
    <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
  </div>

  <div v-else-if="request" class="mx-auto flex max-w-3xl flex-col gap-page">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <button
          type="button"
          class="mb-1 text-body text-ink-muted hover:text-ink hover:underline"
          @click="router.push({ name: 'requests.index' })"
        >
          ← Back to requests
        </button>
        <h1 class="text-page-title">Request #{{ request.id }}</h1>
        <p class="mt-0.5 text-small text-ink-muted">{{ request.destination }}</p>
      </div>

      <StatusBadge :status="request.status" />
    </div>

    <div
      v-if="request.disapproval_reason"
      class="rounded-card border border-red-200 bg-red-50 p-card text-small text-red-800"
    >
      <p class="font-medium">Disapproved</p>
      <p class="mt-1">{{ request.disapproval_reason }}</p>
    </div>

    <!-- Shown while the request waits for approval again after an edit. -->
    <div
      v-if="request.edit_reason && request.status === 'pending'"
      class="rounded-card border-l-4 border-secondary bg-secondary-50 p-card text-small text-secondary-700"
    >
      <p class="font-medium">Edited after approval</p>
      <p class="mt-1">Reason: {{ request.edit_reason }}</p>
    </div>

    <BaseCard title="Request for use of vehicle" :padded="false">
      <dl class="divide-y divide-line">
        <div
          v-for="row in rows"
          :key="row.label"
          class="grid grid-cols-1 gap-1 px-card py-3 sm:grid-cols-3 sm:gap-4"
        >
          <dt class="text-small text-ink-muted">{{ row.label }}</dt>
          <dd class="text-body sm:col-span-2 sm:capitalize">{{ row.value || '—' }}</dd>
        </div>
      </dl>
    </BaseCard>

    <div class="flex flex-wrap justify-end gap-3">
      <template v-if="auth.isAdministrator && request.status === 'pending'">
        <BaseButton @click="approveOpen = true">Approve</BaseButton>
        <BaseButton variant="outline" @click="disapproveOpen = true">
          Disapprove
        </BaseButton>
      </template>

      <BaseButton
        v-if="canEdit"
        variant="outline"
        @click="router.push({ name: 'requests.edit', params: { id: request.id } })"
      >
        Edit
      </BaseButton>
    </div>

    <ApproveAssignModal
      :request="approveOpen ? request : null"
      @close="approveOpen = false"
      @done="onApproved"
    />

    <DisapproveRequestModal
      :request="disapproveOpen ? request : null"
      @close="disapproveOpen = false"
      @done="onDisapproved"
    />
  </div>
</template>