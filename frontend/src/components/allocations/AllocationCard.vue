<script setup>
import { computed } from 'vue'
import { formatDate, formatTime } from '@/lib/format'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import TripTypeBadge from '@/components/ui/TripTypeBadge.vue'

// One allocation of the logged-in faculty member.
const props = defineProps({
  allocation: { type: Object, required: true },
  pendingChange: { type: Object, default: null },
})

defineEmits(['reschedule'])

// Only a scheduled trip can change date, and only one request can wait at a time.
const canReschedule = computed(() => props.allocation.status === 'scheduled' && !props.pendingChange)
</script>

<template>
  <article class="flex flex-col gap-3 rounded-card border border-line bg-white p-card">
    <div class="flex flex-wrap items-start justify-between gap-2">
      <div class="min-w-0">
        <p class="truncate font-medium text-ink">{{ allocation.trip?.destination ?? '—' }}</p>
        <p class="truncate text-small text-ink-muted">{{ allocation.trip?.purpose || '—' }}</p>
      </div>
      <div class="flex items-center gap-2">
        <TripTypeBadge :type="allocation.vehicle_request?.trip_type" />
        <StatusBadge :status="allocation.status ?? 'scheduled'" />
      </div>
    </div>

    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <div class="rounded-card bg-surface p-3">
        <p class="text-xs text-ink-muted">Date</p>
        <p class="mt-1 text-small font-medium text-ink">
          {{ formatDate(allocation.trip?.trip_date) }}
        </p>
        <p class="mt-2 text-xs text-ink-muted">Departure → estimated return</p>
        <p class="mt-1 text-small font-medium text-ink">
          {{ formatTime(allocation.trip?.departure_time) }} →
          {{ formatTime(allocation.trip?.estimated_return_time) }}
        </p>
      </div>

      <div class="rounded-card bg-surface p-3">
        <p class="text-xs text-ink-muted">Vehicle</p>
        <p class="mt-1 text-small font-medium text-ink">
          {{ allocation.vehicle?.vehicle_model ?? '—' }} ({{ allocation.vehicle?.plate_number ?? '—' }})
        </p>
        <p class="mt-2 text-xs text-ink-muted">Driver</p>
        <p class="mt-1 text-small font-medium text-ink">{{ allocation.driver?.name ?? '—' }}</p>
        <p v-if="allocation.driver?.contact_number" class="mt-1 text-xs text-ink-muted">
          Contact: {{ allocation.driver.contact_number }}
        </p>
      </div>
    </div>

    <p v-if="allocation.notes" class="text-small italic text-ink-muted">Note: {{ allocation.notes }}</p>

    <p
      v-if="pendingChange"
      class="rounded-card border border-secondary-200 bg-secondary-50 p-3 text-small text-secondary-700"
    >
      Date change requested: {{ formatDate(pendingChange.new_date) }} (waiting for the administrator)
    </p>

    <div v-if="canReschedule" class="flex justify-end">
      <BaseButton size="sm" variant="outline" @click="$emit('reschedule', allocation)">
        Request date change
      </BaseButton>
    </div>
  </article>
</template>