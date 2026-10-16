<script setup>
defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  options: { type: Array, default: () => [] }, // [{ value, label, disabled? }]
  placeholder: { type: String, default: 'Select an option' },
  allowEmpty: { type: Boolean, default: false }, // lets the placeholder be picked, e.g. "All status"
  error: { type: String, default: '' },
  required: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
})

defineEmits(['update:modelValue'])
</script>

<template>
  <div>
    <label v-if="label" class="field-label">
      {{ label }}
      <span v-if="required" class="text-red-500">*</span>
    </label>

    <select
      :value="modelValue"
      :disabled="disabled"
      class="field-control appearance-none bg-[length:16px] bg-[right_12px_center] bg-no-repeat pr-10"
      style="background-image: url('data:image/svg+xml;utf8,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%236b7280%22 stroke-width=%222%22><path d=%22M6 9l6 6 6-6%22/></svg>')"
      :class="{ 'field-error': error }"
      @change="$emit('update:modelValue', $event.target.value)"
    >
      <option value="" :disabled="!allowEmpty">{{ placeholder }}</option>
      <option
        v-for="option in options"
        :key="option.value"
        :value="option.value"
        :disabled="option.disabled"
      >
        {{ option.label }}
      </option>
    </select>

    <p v-if="error" class="mt-1 text-small text-red-600">{{ error }}</p>
  </div>
</template>