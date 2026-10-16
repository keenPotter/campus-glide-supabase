<script setup>
import { TRIP_TYPE_LABELS } from '@/lib/format'

defineProps({
  type: { type: String, default: null },
})

const styles = {
  inclusive: 'bg-primary-50 text-primary-700 ring-primary-200',
  exclusive: 'bg-secondary-50 text-secondary-700 ring-secondary-200',
}

const fallback = 'bg-neutral-100 text-ink-muted ring-line'
</script>

<template>
  <span
    class="inline-flex items-center whitespace-nowrap rounded-full px-2.5 py-1 text-small font-medium ring-1 ring-inset"
    :class="styles[type] ?? fallback"
  >
    {{ TRIP_TYPE_LABELS[type] ?? 'Unknown type' }}
  </span>
</template>