<script setup>
import { computed } from 'vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import LoadError from '@/components/ui/LoadError.vue'
import ScheduleSummary from '@/components/trip-schedule/ScheduleSummary.vue'
import MonthCalendar from '@/components/trip-schedule/MonthCalendar.vue'
import WeekCalendar from '@/components/trip-schedule/WeekCalendar.vue'
import TripList from '@/components/trip-schedule/TripList.vue'
import TripDetailsModal from '@/components/trip-schedule/TripDetailsModal.vue'
import { useTripSchedule } from '@/composables/useTripSchedule'

const typeOptions = computed(() => [
  { value: 'inclusive', label: `Inclusive (${inclusiveTripCount.value})`, dot: 'bg-primary' },
  { value: 'exclusive', label: `Exclusive (${exclusiveTripCount.value})`, dot: 'bg-secondary' },
])

const viewOptions = [
  { value: 'month', label: 'Month' },
  { value: 'week', label: 'Week' },
  { value: 'list', label: 'List' },
]

const {
  currentView,
  currentTripType,
  currentDate,
  activeTrip,
  activeTrips,
  activeDateLabel,
  loading,
  loadError,
  currentTripTypeLabel,
  filteredTrips,
  exclusiveTripCount,
  inclusiveTripCount,
  scheduledTripList,
  upcomingTripCount,
  newTripCount,
  monthName,
  daysInMonth,
  firstDayOfMonth,
  weekDays,
  weekRange,
  monthTrips,
  tripDetailRows,
  fetchTrips,
  changeMonth,
  changeWeek,
  isToday,
  isSelectedDate,
  isScheduled,
  getTripCountForDate,
  hasNewTripOnDate,
  getTripsForDate,
  openDay,
  openDate,
  openTripModal,
  selectModalTrip,
  closeTripModal,
  isNewTrip,
} = useTripSchedule()
</script>

<template>
  <div class="flex flex-col gap-page">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-page-title">Trip Schedule</h1>
        <p class="mt-1 text-small text-ink-muted">View scheduled trips and allocation details</p>
      </div>
      <BaseButton variant="outline" size="sm" :disabled="loading" @click="fetchTrips">Refresh</BaseButton>
    </div>

    <SegmentedControl v-model="currentTripType" :options="typeOptions" label="Trip type" />
    <SegmentedControl v-model="currentView" :options="viewOptions" label="Schedule view" />

    <LoadError :message="loadError" @retry="fetchTrips" />

    <ScheduleSummary
      :trip-type-label="currentTripTypeLabel"
      :total="filteredTrips.length"
      :upcoming="upcomingTripCount"
      :new-count="newTripCount"
    />

    <template v-if="currentView === 'month'">
      <MonthCalendar
        :trip-type="currentTripType"
        :month-name="monthName"
        :year="currentDate.getFullYear()"
        :first-day-of-month="firstDayOfMonth"
        :days-in-month="daysInMonth"
        :is-scheduled="isScheduled"
        :get-trip-count-for-date="getTripCountForDate"
        :is-today="isToday"
        :is-selected-date="isSelectedDate"
        :has-new-trip-on-date="hasNewTripOnDate"
        @change-month="changeMonth"
        @open-day="openDay"
      />

      <TripList
        :title="`${currentTripTypeLabel} scheduled trips`"
        :subtitle="`${monthName} ${currentDate.getFullYear()}`"
        :empty-message="`No ${currentTripTypeLabel.toLowerCase()} scheduled trips for this month.`"
        :trips="monthTrips"
        :is-new-trip="isNewTrip"
        @open-trip="openTripModal"
      />
    </template>

    <WeekCalendar
      v-else-if="currentView === 'week'"
      :trip-type="currentTripType"
      :week-range="weekRange"
      :week-days="weekDays"
      :get-trips-for-date="getTripsForDate"
      :is-new-trip="isNewTrip"
      @change-week="changeWeek"
      @open-date="openDate"
      @open-trip="openTripModal"
    />

    <TripList
      v-else
      :title="`${currentTripTypeLabel} scheduled trips`"
      subtitle="All allocated trips of this type"
      :empty-message="`No ${currentTripTypeLabel.toLowerCase()} scheduled trips found.`"
      :trips="scheduledTripList"
      :is-new-trip="isNewTrip"
      @open-trip="openTripModal"
    />

    <TripDetailsModal
      :trip="activeTrip"
      :trips="activeTrips"
      :date-label="activeDateLabel"
      :rows="tripDetailRows"
      :is-new-trip="isNewTrip"
      @select-trip="selectModalTrip"
      @close="closeTripModal"
    />
  </div>
</template>