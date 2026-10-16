<script setup>
import BaseCard from '@/components/ui/BaseCard.vue'
import CalendarHeader from '@/components/trip-schedule/CalendarHeader.vue'

const props = defineProps({
  tripType: { type: String, required: true },
  monthName: { type: String, required: true },
  year: { type: Number, required: true },
  firstDayOfMonth: { type: Number, required: true },
  daysInMonth: { type: Number, required: true },
  isScheduled: { type: Function, required: true },
  getTripCountForDate: { type: Function, required: true },
  isToday: { type: Function, required: true },
  isSelectedDate: { type: Function, required: true },
  hasNewTripOnDate: { type: Function, required: true },
})

const emit = defineEmits(['change-month', 'open-day'])

const weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

const scheduledTone = {
  inclusive: 'border-primary-200 bg-primary-50 text-primary-800 hover:bg-primary-100',
  exclusive: 'border-secondary-200 bg-secondary-50 text-secondary-700 hover:bg-secondary-100',
}

function dayClass(day) {
  return [
    props.isScheduled(day)
      ? scheduledTone[props.tripType]
      : 'border-transparent bg-white text-ink-muted/60',
    props.isSelectedDate(day)
      ? 'ring-2 ring-ink-muted'
      : props.isToday(day)
        ? 'font-bold ring-2 ring-primary-600'
        : '',
  ]
}
</script>

<template>
  <BaseCard>
    <CalendarHeader
      :title="`${monthName} ${year}`"
      :trip-type="tripType"
      prev-label="Previous month"
      next-label="Next month"
      @prev="emit('change-month', -1)"
      @next="emit('change-month', 1)"
    />

    <div class="mb-1 grid grid-cols-7 text-center text-small font-semibold text-ink">
      <span v-for="name in weekdayNames" :key="name">{{ name }}</span>
    </div>

    <div class="grid grid-cols-7 gap-1">
      <div v-for="blank in firstDayOfMonth" :key="'blank-' + blank" />

      <button
        v-for="day in daysInMonth"
        :key="day"
        type="button"
        class="relative flex h-12 items-center justify-center rounded-card border text-body transition disabled:cursor-default sm:h-14"
        :class="dayClass(day)"
        :disabled="!isScheduled(day)"
        @click="emit('open-day', day)"
      >
        {{ day }}

        <span
          v-if="isScheduled(day)"
          class="absolute bottom-0.5 right-0.5 min-w-4 rounded-full bg-white/90 px-1 text-[10px] font-bold leading-4 text-ink"
          :aria-label="`${getTripCountForDate(day)} scheduled trips`"
        >
          {{ getTripCountForDate(day) }}
        </span>

        <span
          v-if="hasNewTripOnDate(day)"
          class="absolute right-1 top-1 h-2 w-2 rounded-full bg-red-500"
          title="New scheduled trip"
          aria-label="New scheduled trip"
        />
      </button>
    </div>
  </BaseCard>
</template>