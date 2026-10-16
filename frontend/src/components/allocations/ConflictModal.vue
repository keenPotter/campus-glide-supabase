<script setup>
import { computed } from 'vue'
import { formatDate, formatTime } from '@/lib/format'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'

// Open when `conflicts` has items. `conflicts` is the list the backend sends with a 422 response.
// A vehicle and a driver that clash with the same trip are shown together in one card.
const props = defineProps({
  conflicts: { type: Array, default: () => [] },
  hint: { type: String, default: '' },
})

const emit = defineEmits(['close'])

const open = computed(() => props.conflicts.length > 0)
const hasVehicle = computed(() => props.conflicts.some((item) => item.type === 'vehicle'))
const hasDriver = computed(() => props.conflicts.some((item) => item.type === 'driver'))

const title = computed(() => {
  if (hasVehicle.value && hasDriver.value) return 'Vehicle and driver unavailable'
  return hasDriver.value ? 'Driver unavailable' : 'Vehicle unavailable'
})

const footer = computed(() => {
  if (props.hint) return props.hint
  if (hasVehicle.value && hasDriver.value) return 'Please select another vehicle and driver.'
  return `Please select another ${hasDriver.value ? 'driver' : 'vehicle'}.`
})

// One card for each conflicting trip.
const groups = computed(() => {
  const byTrip = new Map()

  for (const item of props.conflicts) {
    const key = item.trip_id ?? `${item.type}-${item.subject}`

    if (!byTrip.has(key)) {
      byTrip.set(key, {
        key,
        items: [],
        date: item.date,
        endDate: item.end_date,
        start: item.start,
        end: item.end,
        destination: item.destination,
        driver: item.driver,
        vehicle: item.vehicle,
      })
    }

    byTrip.get(key).items.push(item)
  }

  return [...byTrip.values()].map((group) => {
    const types = group.items.map((item) => item.type)

    return {
      ...group,
      // Only show the driver or vehicle of the other trip when it is not already listed above.
      otherDriver: types.includes('driver') ? null : group.driver,
      otherVehicle: types.includes('vehicle') ? null : group.vehicle,
    }
  })
})

// A multi-day trip shows its first and last day.
function when(group) {
  const days =
    group.endDate && group.endDate !== group.date
      ? `${formatDate(group.date)} – ${formatDate(group.endDate)}`
      : formatDate(group.date)

  return `${days}, ${formatTime(group.start)}${group.end ? ` – ${formatTime(group.end)}` : ''}`
}
</script>

<template>
  <BaseModal :open="open" :title="title" @close="emit('close')">
    <template v-if="open">
      <p class="text-body">
        {{ conflicts.length > 1 ? 'These conflicts were found:' : 'A scheduling conflict was found:' }}
      </p>

      <ul class="mt-3 flex flex-col gap-3">
        <li v-for="group in groups" :key="group.key" class="rounded-card bg-surface p-3 text-small">
          <p v-for="item in group.items" :key="item.type" class="text-ink">
            <span class="text-ink-muted">{{ item.type === 'driver' ? 'Driver' : 'Vehicle' }}:</span>
            <strong> {{ item.subject }}</strong>
          </p>

          <p class="mt-1 text-ink-muted">Already scheduled for {{ when(group) }}.</p>

          <p class="mt-2 text-ink-muted">Current trip</p>
          <p class="mt-1 font-medium text-ink">{{ group.destination ?? '—' }}</p>
          <p v-if="group.otherDriver" class="mt-1 text-ink-muted">Driver: {{ group.otherDriver }}</p>
          <p v-if="group.otherVehicle" class="text-ink-muted">Vehicle: {{ group.otherVehicle }}</p>
        </li>
      </ul>

      <p class="mt-3 text-body">{{ footer }}</p>
    </template>

    <template #footer>
      <BaseButton @click="emit('close')">OK</BaseButton>
    </template>
  </BaseModal>
</template>