<script setup>
import { computed } from 'vue'
import { STATUS_LABELS } from '@/lib/format'

const props = defineProps({
  status: { type: String, required: true },
})

const primary = 'bg-primary-50 text-primary-700 ring-primary-200'
const secondary = 'bg-secondary-50 text-secondary-700 ring-secondary-200'
const danger = 'bg-red-50 text-red-700 ring-red-200'

const styles = {
  // Vehicle requests
  pending: secondary,
  approved: primary,
  disapproved: danger,
  // Trips and maintenance
  scheduled: primary,
  completed: primary,
  upcoming: secondary,
  overdue: danger,
  in_progress: 'bg-blue-50 text-blue-700 ring-blue-200',
}

const fallback = 'bg-neutral-100 text-ink-muted ring-line'

const label = computed(() => STATUS_LABELS[props.status] ?? props.status)
const classes = computed(() => styles[props.status] ?? fallback)
</script>

<template>
  <span
    class="inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-1 text-small font-medium ring-1 ring-inset"
    :class="classes"
  >
    {{ label }}
  </span>
</template>