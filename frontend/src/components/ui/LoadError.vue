<script setup>
import BaseButton from '@/components/ui/BaseButton.vue'

defineProps({
  message: { type: String, default: '' },
})

defineEmits(['retry'])
</script>

<template>
  <div
    v-if="message"
    class="flex flex-wrap items-center justify-between gap-3 rounded-card border border-red-200 bg-red-50 p-card text-small text-red-800"
  >
    <p>{{ message }}</p>
    <BaseButton size="sm" variant="outline" @click="$emit('retry')">Try again</BaseButton>
  </div>
</template>