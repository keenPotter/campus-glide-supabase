<script setup>
import { computed, ref } from 'vue'
import { useAllocations } from '@/composables/useAllocations'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import LoadError from '@/components/ui/LoadError.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import AllocationCard from '@/components/allocations/AllocationCard.vue'
import RescheduleModal from '@/components/allocations/RescheduleModal.vue'
import RescheduleRequestCard from '@/components/allocations/RescheduleRequestCard.vue'

// The allocation page for faculty: their own allocations and date change requests.
const toast = useToast()

const {
  allocations,
  dateChanges,
  loading,
  loadError,
  counts,
  pendingDateChanges,
  pendingByAllocation,
  load,
} = useAllocations()

const typeFilter = ref('')
const rescheduleTarget = ref(null)

const tones = {
  primary: 'bg-primary-50 text-primary-700',
  secondary: 'bg-secondary-50 text-secondary-700',
}

const stats = computed(() => [
  { label: 'Scheduled', value: counts.value.scheduled, tone: 'primary' },
  { label: 'Ongoing', value: counts.value.in_progress, tone: 'secondary' },
  { label: 'Done', value: counts.value.completed, tone: 'primary' },
  { label: 'Date changes waiting', value: pendingDateChanges.value.length, tone: 'secondary' },
])

function countOf(type) {
  return allocations.value.filter((item) => item.vehicle_request?.trip_type === type).length
}

const typeOptions = computed(() => [
  { value: '', label: `All (${allocations.value.length})` },
  { value: 'inclusive', label: `Inclusive (${countOf('inclusive')})`, dot: 'bg-primary' },
  { value: 'exclusive', label: `Exclusive (${countOf('exclusive')})`, dot: 'bg-secondary' },
])

// The trip type is the one chosen on the request form.
const visible = computed(() =>
  typeFilter.value
    ? allocations.value.filter((item) => item.vehicle_request?.trip_type === typeFilter.value)
    : allocations.value,
)

function onRescheduleSaved(message) {
  rescheduleTarget.value = null
  toast.success(message)
  load()
}
</script>

<template>
  <div class="flex flex-col gap-page">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-page-title">My Allocations</h1>
        <p class="mt-1 text-small text-ink-muted">
          The vehicle and driver assigned to your approved requests.
        </p>
      </div>
      <BaseButton variant="outline" size="sm" :disabled="loading" @click="load">Refresh</BaseButton>
    </div>

    <LoadError :message="loadError" @retry="load" />

    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <div v-for="stat in stats" :key="stat.label" class="stat-card">
        <span
          class="inline-flex rounded-full px-2 py-0.5 text-small font-medium"
          :class="tones[stat.tone]"
        >
          {{ stat.label }}
        </span>
        <p class="mt-2 text-2xl font-bold">{{ stat.value }}</p>
      </div>
    </div>

    <SegmentedControl v-model="typeFilter" :options="typeOptions" label="Trip type" />

    <BaseCard title="My allocations" :subtitle="`${visible.length} shown`">
      <div v-if="loading" class="flex justify-center p-8">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>

      <EmptyState
        v-else-if="!visible.length"
        title="No allocations found"
        :message="
          typeFilter
            ? `You have no ${typeFilter} allocations.`
            : 'Once the administrator assigns a vehicle and driver to your approved request, it appears here.'
        "
      />

      <div v-else class="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <AllocationCard
          v-for="item in visible"
          :key="item.id"
          :allocation="item"
          :pending-change="pendingByAllocation[item.id] ?? null"
          @reschedule="rescheduleTarget = $event"
        />
      </div>
    </BaseCard>

    <BaseCard v-if="dateChanges.length" title="My date change requests">
      <div class="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <RescheduleRequestCard v-for="item in dateChanges" :key="item.id" :item="item" />
      </div>
    </BaseCard>

    <RescheduleModal
      :allocation="rescheduleTarget"
      :is-admin="false"
      @close="rescheduleTarget = null"
      @saved="onRescheduleSaved"
    />
  </div>
</template>