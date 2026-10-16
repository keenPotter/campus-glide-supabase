<script setup>
import { useRouter } from 'vue-router'
import BaseButton from '@/components/ui/BaseButton.vue'

const router = useRouter()
</script>

<template>
  <div class="flex flex-col items-center justify-center gap-3 py-24 text-center">
    <p class="text-page-title">404</p>
    <p class="text-small text-ink-muted">That page does not exist.</p>
    <BaseButton @click="router.push({ name: 'dashboard' })">Back to dashboard</BaseButton>
  </div>
</template>