<script setup>
defineProps({
  modelValue: { type: String, required: true },
  options: { type: Array, required: true }, // [{ value, label, dot? }]
  label: { type: String, default: '' },
})

defineEmits(['update:modelValue'])
</script>

<template>
  <div
    class="grid gap-1 rounded-card bg-line p-1"
    :style="{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }"
    role="tablist"
    :aria-label="label"
  >
    <button
      v-for="option in options"
      :key="option.value"
      type="button"
      role="tab"
      :aria-selected="modelValue === option.value"
      class="flex h-control items-center justify-center gap-2 rounded-card text-small font-semibold transition"
      :class="
        modelValue === option.value
          ? 'bg-white text-primary-700 shadow-card'
          : 'text-ink hover:bg-white/50'
      "
      @click="$emit('update:modelValue', option.value)"
    >
      <span v-if="option.dot" class="h-2 w-2 rounded-full" :class="option.dot" />
      {{ option.label }}
    </button>
  </div>
</template>