<script setup>
import { computed } from 'vue'

const props = defineProps({
  meta: { type: Object, default: null },
})

const emit = defineEmits(['change'])

// Builds the list of buttons: 1 ... 4 5 6 ... 10
// Long page lists are shortened with "…" so the bar always fits the screen.
const pages = computed(() => {
  if (!props.meta) return []

  const last = props.meta.last_page
  const current = props.meta.current_page

  if (last <= 7) {
    return Array.from({ length: last }, (_, i) => i + 1)
  }

  const items = [1]
  const start = Math.max(2, current - 1)
  const end = Math.min(last - 1, current + 1)

  if (start > 2) items.push('…')
  for (let page = start; page <= end; page++) items.push(page)
  if (end < last - 1) items.push('…')

  items.push(last)
  return items
})

const box =
  'flex h-10 w-10 items-center justify-center rounded-card border-2 text-body font-semibold transition sm:h-11 sm:w-11'
</script>

<template>
  <div
    v-if="meta && meta.last_page > 1"
    class="flex flex-col items-center gap-3 border-t border-line px-card py-4"
  >
    <nav class="flex flex-wrap items-center justify-center gap-2" aria-label="Pagination">
      <button
        type="button"
        :class="[box, 'border-line bg-white text-ink hover:bg-neutral-50 disabled:cursor-not-allowed disabled:opacity-40']"
        :disabled="meta.current_page <= 1"
        aria-label="Previous page"
        @click="emit('change', meta.current_page - 1)"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M15 18l-6-6 6-6" />
        </svg>
      </button>

      <template v-for="(page, index) in pages" :key="`${page}-${index}`">
        <span v-if="page === '…'" class="px-1 text-ink-muted">…</span>

        <button
          v-else
          type="button"
          :class="[
            box,
            page === meta.current_page
              ? 'border-primary bg-primary text-white'
              : 'border-line bg-white text-ink hover:bg-neutral-50',
          ]"
          :aria-label="`Page ${page}`"
          :aria-current="page === meta.current_page ? 'page' : undefined"
          @click="emit('change', page)"
        >
          {{ page }}
        </button>
      </template>

      <button
        type="button"
        :class="[box, 'border-line bg-white text-ink hover:bg-neutral-50 disabled:cursor-not-allowed disabled:opacity-40']"
        :disabled="meta.current_page >= meta.last_page"
        aria-label="Next page"
        @click="emit('change', meta.current_page + 1)"
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 18l6-6-6-6" />
        </svg>
      </button>
    </nav>

    <p class="text-small text-ink-muted">
      Page {{ meta.current_page }} of {{ meta.last_page }} · {{ meta.total }} records
    </p>
  </div>
</template>