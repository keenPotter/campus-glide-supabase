<script setup>
import BaseCard from '@/components/ui/BaseCard.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import TripTypeBadge from '@/components/ui/TripTypeBadge.vue'
import { dayOfMonth, formatTime, shortMonth } from '@/lib/format'
import {
  driverName,
  getTripStartDate,
  requesterName,
  tripDateRange,
  tripType,
  vehicleName,
} from '@/lib/trips'

defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  emptyMessage: { type: String, default: 'No scheduled trips found.' },
  trips: { type: Array, required: true },
  isNewTrip: { type: Function, required: true },
})

defineEmits(['open-trip'])
</script>

<template>
  <BaseCard :title="title" :subtitle="subtitle" :padded="false">
    <template #actions>
      <span
        class="inline-flex h-7 min-w-8 items-center justify-center rounded-full bg-primary-50 px-2.5 text-small font-semibold text-primary-700"
      >
        {{ trips.length }}
      </span>
    </template>

    <EmptyState v-if="!trips.length" title="No scheduled trips" :message="emptyMessage" />

    <ul v-else class="divide-y divide-line">
      <li v-for="trip in trips" :key="trip.id">
        <button
          type="button"
          class="flex w-full items-center gap-3 px-card py-3 text-left hover:bg-neutral-50"
          @click="$emit('open-trip', trip)"
        >
          <div class="w-12 shrink-0 text-center">
            <p class="text-section-title leading-none">{{ dayOfMonth(getTripStartDate(trip)) }}</p>
            <p class="text-small text-ink-muted">{{ shortMonth(getTripStartDate(trip)) }}</p>
          </div>

          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <p class="truncate font-medium text-ink">{{ trip.destination || 'Trip' }}</p>
              <div class="flex items-center gap-2">
                <span
                  v-if="isNewTrip(trip)"
                  class="h-2 w-2 rounded-full bg-red-500"
                  title="New scheduled trip"
                  aria-label="New scheduled trip"
                />
                <TripTypeBadge :type="tripType(trip)" />
              </div>
            </div>

            <p class="mt-1 truncate text-small text-ink-muted">{{ trip.purpose || '—' }}</p>
            <p class="mt-1 text-small text-ink-muted">
              {{ requesterName(trip) }} · {{ tripDateRange(trip) }} ·
              {{ formatTime(trip.departure_time) }} · {{ vehicleName(trip) }} ·
              {{ driverName(trip) }}
            </p>
          </div>

          <span class="text-xl text-ink-muted">›</span>
        </button>
      </li>
    </ul>
  </BaseCard>
</template>