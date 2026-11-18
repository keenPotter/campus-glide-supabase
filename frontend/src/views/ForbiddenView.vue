<script setup>
import { RouterLink } from 'vue-router'
import BaseCard from '@/components/ui/BaseCard.vue'
</script>

<template>
  <div class="mx-auto flex min-h-[60vh] max-w-xl items-center">
    <BaseCard class="w-full text-center">
      <p class="text-sm font-bold uppercase tracking-wide text-red-600">403 Forbidden</p>
      <h1 class="mt-2 text-page-title">Access denied</h1>
      <p class="mt-2 text-body text-ink-muted">You do not have permission to view this page.</p>
      <RouterLink
        class="mt-6 inline-flex h-control items-center justify-center rounded-card bg-primary px-4 text-small font-semibold text-white transition hover:bg-primary-700"
        :to="{ name: 'dashboard' }"
      >
        Return to dashboard
      </RouterLink>
    </BaseCard>
  </div>
</template>
