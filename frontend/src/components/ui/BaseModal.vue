<script setup>
defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
})

const emit = defineEmits(['close'])
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-150"
      enter-from-class="opacity-0"
      leave-active-class="transition duration-150"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-0 sm:items-center sm:p-page"
        @click.self="emit('close')"
      >
        <div
          class="max-h-[90vh] w-full overflow-y-auto rounded-t-card bg-white shadow-pop sm:max-w-lg sm:rounded-card"
        >
          <header class="flex items-start justify-between gap-4 border-b border-line px-card py-card">
            <div>
              <h2 class="text-section-title">{{ title }}</h2>
              <p v-if="subtitle" class="mt-0.5 text-small text-ink-muted">{{ subtitle }}</p>
            </div>
            <button
              type="button"
              class="rounded-card p-1 text-ink-muted hover:bg-neutral-100"
              @click="emit('close')"
            >
              <span class="sr-only">Close</span>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 6 6 18M6 6l12 12" />
              </svg>
            </button>
          </header>

          <div class="p-card">
            <slot />
          </div>

          <footer v-if="$slots.footer" class="flex justify-end gap-3 border-t border-line px-card py-card">
            <slot name="footer" />
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>