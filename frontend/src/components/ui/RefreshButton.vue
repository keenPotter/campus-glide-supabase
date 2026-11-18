<script setup>
defineProps({
  loading: { type: Boolean, default: false },
  label: { type: String, default: 'Refresh data' },
})

defineEmits(['click'])
</script>

<template>
  <button
    type="button"
    class="inline-flex h-8 items-center justify-center rounded-card border border-line bg-white px-2 text-small font-medium text-ink transition hover:bg-neutral-100 disabled:cursor-not-allowed disabled:opacity-50 md:h-9 md:px-3"
    :disabled="loading"
    :title="label"
    :aria-label="label"
    @click="$emit('click')"
  >
    Refresh
  </button>
</template>
