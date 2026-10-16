<script setup>
import { computed } from 'vue'

const props = defineProps({
  variant: { type: String, default: 'primary' }, // primary | secondary | outline | ghost | danger
  size: { type: String, default: 'md' }, // md | sm
  type: { type: String, default: 'button' },
  loading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  block: { type: Boolean, default: false },
})

const variants = {
  primary: 'bg-primary text-white hover:bg-primary-600 active:bg-primary-700',
  secondary: 'bg-secondary text-white hover:bg-secondary-600 active:bg-secondary-700',
  outline: 'border border-line bg-white text-ink hover:bg-neutral-200 hover:text-ink hover:underline',
  ghost: 'cursor-pointer text-ink-muted underline-offset-4 hover:bg-neutral-100 hover:text-ink hover:underline',
  danger: 'bg-red-600 text-white hover:bg-red-700',
}

const classes = computed(() => [
  'inline-flex items-center justify-center gap-2 rounded-card font-medium transition',
  'disabled:cursor-not-allowed disabled:opacity-50',
  props.size === 'sm' ? 'h-8 px-2 text-small md:h-9 md:px-3' : 'h-control px-4 md:px-5 text-body',
  props.block ? 'w-full' : '',
  variants[props.variant] ?? variants.primary,
])
</script>

<template>
  <button :type="type" :class="classes" :disabled="disabled || loading">
    <span
      v-if="loading"
      class="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
    />
    <slot />
  </button>
</template>