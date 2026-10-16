<script setup>
import { computed } from 'vue'
import BaseCard from '@/components/ui/BaseCard.vue'

const props = defineProps({
  tripTypeLabel: { type: String, required: true },
  total: { type: Number, required: true },
  upcoming: { type: Number, required: true },
  newCount: { type: Number, required: true },
})

const items = computed(() => [
  {
    label: 'Total scheduled',
    value: props.total,
    icon: 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM9 15l2 2 4-4',
  },
  {
    label: 'Upcoming',
    value: props.upcoming,
    icon: 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM12 7v5l3.5 2',
  },
  {
    label: 'Unviewed',
    value: props.newCount,
    icon: 'M18 9a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
  },
])
</script>

<template>
  <BaseCard :title="`${tripTypeLabel} trips`" subtitle="Schedule summary">
    <div class="grid grid-cols-3 gap-2">
      <div
        v-for="item in items"
        :key="item.label"
        class="flex flex-col items-center gap-1 rounded-card bg-surface px-1 py-3 text-center"
      >
        <svg
          class="h-5 w-5 text-primary-700"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.8"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path :d="item.icon" />
        </svg>
        <p class="text-section-title">{{ item.value }}</p>
        <p class="text-small text-ink-muted">{{ item.label }}</p>
      </div>
    </div>
  </BaseCard>
</template>