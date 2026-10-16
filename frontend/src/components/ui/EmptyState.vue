<script setup>
defineProps({
  title: { type: String, default: 'Nothing here yet' },
  message: { type: String, default: '' },
})
</script>

<template>
  <div class="flex flex-col items-center justify-center gap-2 px-card py-12 text-center">
    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-neutral-100 text-ink-muted">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M3 7h18M3 12h18M3 17h10" />
      </svg>
    </div>
    <p class="text-body font-medium text-ink">{{ title }}</p>
    <p v-if="message" class="max-w-sm text-small text-ink-muted">{{ message }}</p>
    <slot />
  </div>
</template>