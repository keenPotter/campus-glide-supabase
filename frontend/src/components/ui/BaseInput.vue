<script setup>
import { computed, ref } from 'vue'
import { Eye, EyeOff, Search } from 'lucide-vue-next'

const props = defineProps({
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
  maxLength: { type: [String, Number], default: undefined },
  step: { type: [String, Number], default: undefined },
  autocomplete: { type: String, default: undefined },
  name: { type: String, default: undefined },
  id: { type: String, default: undefined },
  showPasswordToggle: { type: Boolean, default: false },
})

const emit = defineEmits(['update:modelValue'])

const passwordVisible = ref(false)
const hasPassword = computed(() => String(props.modelValue ?? '').length > 0)
const inputType = computed(() => (
  props.showPasswordToggle && props.type === 'password' && hasPassword.value && passwordVisible.value
    ? 'text'
    : props.type
))

function updateValue(event) {
  const value = event.target.value
  if (!value) passwordVisible.value = false
  emit('update:modelValue', value)
}
</script>

<template>
  <div class="min-w-0">
    <label v-if="label" :for="id" class="field-label">
      {{ label }}
      <span v-if="required" class="text-red-500">*</span>
    </label>

    <div :class="type === 'search' || (showPasswordToggle && type === 'password') ? 'relative' : ''">
      <Search
        v-if="type === 'search'"
        :size="16"
        class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted"
        aria-hidden="true"
      />
      <input
        :type="inputType"
        :value="modelValue"
        :placeholder="placeholder"
        :disabled="disabled"
        :required="required"
        :min="min"
        :max="max"
        :maxlength="maxLength"
        :step="step"
        :autocomplete="autocomplete"
        :name="name"
        :id="id"
        class="field-control"
        :class="[
          { 'field-error': error },
          type === 'search' ? 'pl-10' : '',
          showPasswordToggle && type === 'password' ? 'pr-10' : '',
          showPasswordToggle && type === 'password' ? 'password-toggle-input' : '',
        ]"
        @input="updateValue"
      />
      <button
        v-if="showPasswordToggle && type === 'password' && hasPassword"
        type="button"
        class="absolute inset-y-0 right-0 flex items-center rounded pr-3 text-ink-muted hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400"
        :aria-label="passwordVisible ? 'Hide password' : 'Show password'"
        :aria-pressed="passwordVisible"
        @mousedown.prevent
        @click="passwordVisible = !passwordVisible"
      >
        <EyeOff v-if="passwordVisible" :size="18" aria-hidden="true" />
        <Eye v-else :size="18" aria-hidden="true" />
      </button>
    </div>

    <p v-if="error" class="mt-1 text-small text-red-600">{{ error }}</p>
    <p v-else-if="hint" class="mt-1 text-small text-ink-muted">{{ hint }}</p>
  </div>
</template>

<style scoped>
.password-toggle-input::-ms-reveal {
  display: none;
}
</style>