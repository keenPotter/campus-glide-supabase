<script setup>
import BaseCard from '@/components/ui/BaseCard.vue'
import CalendarHeader from '@/components/trip-schedule/CalendarHeader.vue'
import { formatTime } from '@/lib/format'
import { tripType as getTripType } from '@/lib/trips'

defineProps({
  tripType: { type: String, required: true },
  weekRange: { type: String, required: true },
  weekDays: { type: Array, required: true },
  getTripsForDate: { type: Function, required: true },
  isNewTrip: { type: Function, required: true },
})

const emit = defineEmits(['change-week', 'open-date', 'open-trip'])

const eventTone = {
  inclusive: 'border-primary bg-primary-50',
  exclusive: 'border-secondary bg-secondary-50',
}
</script>

<template>
  <BaseCard>
    <CalendarHeader
      :title="weekRange"
      :trip-type="tripType"
      prev-label="Previous week"
      next-label="Next week"
      @prev="emit('change-week', -1)"
      @next="emit('change-week', 1)"
    />

    <div class="overflow-x-auto">
      <div class="grid grid-cols-[repeat(7,minmax(90px,1fr))] gap-2">
        <div
          v-for="day in weekDays"
          :key="day.date"
          class="overflow-hidden rounded-card border border-line bg-white"
        >
          <button
            type="button"
            class="w-full py-2 text-center disabled:opacity-60"
            :class="
              getTripsForDate(day.date).length ? 'bg-primary-50 text-primary-700' : 'bg-surface'
            "
            :disabled="!getTripsForDate(day.date).length"
            @click="emit('open-date', day.date)"
          >
            <span class="block text-small">{{ day.name }}</span>
            <strong class="block text-section-title">{{ day.number }}</strong>
          </button>

          <div class="flex min-h-24 flex-col gap-1 p-1">
            <button
              v-for="trip in getTripsForDate(day.date)"
              :key="trip.id"
              type="button"
              class="rounded-card border-l-4 p-2 text-left"
              :class="eventTone[getTripType(trip)]"
              @click="emit('open-trip', trip)"
            >
              <div class="flex items-center justify-between gap-1">
                <strong class="text-small">{{ formatTime(trip.departure_time) }}</strong>
                <span
                  v-if="isNewTrip(trip)"
                  class="h-2 w-2 rounded-full bg-red-500"
                  title="New scheduled trip"
                  aria-label="New scheduled trip"
                />
              </div>
              <span class="mt-0.5 block truncate text-small">{{ trip.destination }}</span>
            </button>

            <span v-if="!getTripsForDate(day.date).length" class="mt-4 text-center text-ink-muted/60">
              —
            </span>
          </div>
        </div>
      </div>
    </div>
  </BaseCard>
</template>