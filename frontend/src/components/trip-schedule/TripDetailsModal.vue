<script setup>
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import TripTypeBadge from '@/components/ui/TripTypeBadge.vue'
import { formatTime } from '@/lib/format'
import { driverName, tripType, vehicleName } from '@/lib/trips'

defineProps({
  trip: { type: Object, default: null },
  trips: { type: Array, default: () => [] },
  dateLabel: { type: String, default: '' },
  rows: { type: Array, default: () => [] },
  isNewTrip: { type: Function, required: true },
})

defineEmits(['close', 'select-trip'])
</script>

<template>
  <BaseModal
    :open="Boolean(trip)"
    :title="dateLabel || trip?.destination || 'Trip details'"
    :subtitle="trips.length > 1 ? `${trips.length} trips scheduled for this date` : 'Scheduled trip'"
    @close="$emit('close')"
  >
    <template v-if="trip">
      <div v-if="trips.length > 1" class="mb-4 flex max-h-56 flex-col gap-2 overflow-y-auto">
        <button
          v-for="item in trips"
          :key="item.id"
          type="button"
          class="flex w-full items-center gap-3 rounded-card border p-3 text-left"
          :class="
            item.id === trip.id
              ? 'border-primary bg-primary-50'
              : 'border-line bg-white hover:bg-neutral-50'
          "
          @click="$emit('select-trip', item)"
        >
          <TripTypeBadge :type="tripType(item)" />
          <span class="min-w-0 flex-1">
            <strong class="block truncate text-small">
              {{ item.destination || 'Destination not specified' }}
            </strong>
            <span class="block truncate text-small text-ink-muted">
              {{ formatTime(item.departure_time) }} · {{ vehicleName(item) }} · {{ driverName(item) }}
            </span>
          </span>
          <span
            v-if="isNewTrip(item)"
            class="h-2 w-2 shrink-0 rounded-full bg-red-500"
            aria-label="Unviewed trip"
          />
          <span class="text-ink-muted">›</span>
        </button>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <TripTypeBadge :type="tripType(trip)" />
        <StatusBadge :status="trip.trip_status || 'scheduled'" />
      </div>

      <h3 class="mt-2 text-section-title">{{ trip.destination || 'Trip details' }}</h3>

      <dl class="mt-3 divide-y divide-line border-t border-line">
        <div v-for="row in rows" :key="row.label" class="flex items-start justify-between gap-4 py-2.5">
          <dt class="text-small text-ink-muted">{{ row.label }}</dt>
          <dd class="max-w-[62%] break-words text-right text-small font-medium">{{ row.value }}</dd>
        </div>
      </dl>
    </template>

    <template #footer>
      <BaseButton variant="outline" @click="$emit('close')">Close</BaseButton>
    </template>
  </BaseModal>
</template>