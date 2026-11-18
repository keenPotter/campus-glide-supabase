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
    class="mb-3 flex items-center justify-center gap-3 rounded-card p-2"
    :class="tripType === 'exclusive' ? 'bg-secondary-50' : 'bg-primary-50'"
  >
    <h2 class="min-w-0 text-center text-section-title">{{ title }}</h2>

    <div class="flex shrink-0 items-center gap-2">
      <button
        type="button"
        class="flex h-control w-control items-center justify-center rounded-card bg-white text-xl text-ink hover:bg-neutral-100"
        :aria-label="prevLabel"
        @click="$emit('prev')"
      >
        ‹
      </button>

      <button
        type="button"
        class="flex h-control w-control items-center justify-center rounded-card bg-white text-xl text-ink hover:bg-neutral-100"
        :aria-label="nextLabel"
        @click="$emit('next')"
      >
        ›
      </button>
    </div>
  </div>
</template>