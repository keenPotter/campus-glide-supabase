<script setup>
defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  rows: { type: Number, default: 3 },
  error: { type: String, default: '' },
  required: { type: Boolean, default: false },
  maxlength: { type: Number, default: 500 },
})

defineEmits(['update:modelValue'])
</script>

<template>
  <div>
    <label v-if="label" class="field-label">
      {{ label }}
      <span v-if="required" class="text-red-500">*</span>
    </label>

    <textarea
      :value="modelValue"
      :rows="rows"
      :placeholder="placeholder"
      :maxlength="maxlength"
      class="field-control h-auto py-3"
      :class="{ 'field-error': error }"
      @input="$emit('update:modelValue', $event.target.value)"
    />

    <p v-if="error" class="mt-1 text-small text-red-600">{{ error }}</p>
  </div>
</template>