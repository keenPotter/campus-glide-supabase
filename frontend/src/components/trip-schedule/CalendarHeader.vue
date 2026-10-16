<script setup>
defineProps({
  title: { type: String, required: true },
  tripType: { type: String, required: true },
  prevLabel: { type: String, default: 'Previous' },
  nextLabel: { type: String, default: 'Next' },
})

defineEmits(['prev', 'next'])
</script>

<template>
  <div
    class="mb-3 flex items-center justify-between gap-2 rounded-card p-2"
    :class="tripType === 'exclusive' ? 'bg-secondary-50' : 'bg-primary-50'"
  >
    <button
      type="button"
      class="flex h-control w-control shrink-0 items-center justify-center rounded-card bg-white text-xl text-ink hover:bg-neutral-100"
      :aria-label="prevLabel"
      @click="$emit('prev')"
    >
      ‹
    </button>

    <h2 class="text-center text-section-title">{{ title }}</h2>

    <button
      type="button"
      class="flex h-control w-control shrink-0 items-center justify-center rounded-card bg-white text-xl text-ink hover:bg-neutral-100"
      :aria-label="nextLabel"
      @click="$emit('next')"
    >
      ›
    </button>
  </div>
</template>