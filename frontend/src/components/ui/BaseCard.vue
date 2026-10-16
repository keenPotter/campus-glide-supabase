<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  padded: { type: Boolean, default: true },
})
</script>

<template>
  <section class="rounded-card border border-line bg-white shadow-sm">
    <header
      v-if="title || $slots.actions"
      class="flex flex-col gap-2 border-b border-line px-card py-card sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="flex-1 min-w-0">
        <h2 v-if="title" class="text-section-title truncate">{{ title }}</h2>
        <p v-if="subtitle" class="mt-0.5 text-small text-ink-muted">{{ subtitle }}</p>
      </div>
      <slot name="actions" />
    </header>

    <div :class="padded ? 'p-card' : ''">
      <slot />
    </div>
  </section>
</template>