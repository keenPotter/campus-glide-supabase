<script setup>
import { useToast } from '@/composables/useToast'

const { toasts, dismiss } = useToast()

const styles = {
  success: 'border-primary-200 bg-primary-50 text-primary-800',
  error: 'border-red-200 bg-red-50 text-red-800',
  info: 'border-line bg-white text-ink',
}
</script>

<template>
  <Teleport to="body">
    <div class="pointer-events-none fixed inset-x-0 top-page z-[60] flex flex-col items-center gap-2 px-page">
      <TransitionGroup
        enter-active-class="transition duration-200"
        enter-from-class="-translate-y-2 opacity-0"
        leave-active-class="transition duration-150"
        leave-to-class="opacity-0"
      >
        <div
          v-for="toast in toasts"
          :key="toast.id"
          class="pointer-events-auto w-full max-w-md cursor-pointer rounded-card border px-card py-3 text-small shadow-pop"
          :class="styles[toast.type]"
          @click="dismiss(toast.id)"
        >
          {{ toast.message }}
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>