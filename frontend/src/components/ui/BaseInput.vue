<script setup>
defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  type: { type: String, default: 'text' },
  placeholder: { type: String, default: '' },
  error: { type: String, default: '' },
  hint: { type: String, default: '' },
  required: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  min: { type: [String, Number], default: undefined },
  max: { type: [String, Number], default: undefined },
  step: { type: [String, Number], default: undefined },
})

defineEmits(['update:modelValue'])
</script>

<template>
  <div>
    <label v-if="label" class="field-label">
      {{ label }}
      <span v-if="required" class="text-red-500">*</span>
    </label>

    <input
      :type="type"
      :value="modelValue"
      :placeholder="placeholder"
      :disabled="disabled"
      :min="min"
      :max="max"
      :step="step"
      class="field-control"
      :class="{ 'field-error': error }"
      @input="$emit('update:modelValue', $event.target.value)"
    />

    <p v-if="error" class="mt-1 text-small text-red-600">{{ error }}</p>
    <p v-else-if="hint" class="mt-1 text-small text-ink-muted">{{ hint }}</p>
  </div>
</template>