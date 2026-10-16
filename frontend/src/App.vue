<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AuthLayout from '@/layouts/AuthLayout.vue'
import DashboardLayout from '@/layouts/DashboardLayout.vue'
import ToastHost from '@/components/ui/ToastHost.vue'

const route = useRoute()
const auth = useAuthStore()

const layout = computed(() =>
  auth.isAuthenticated && !route.meta.guestOnly ? DashboardLayout : AuthLayout,
)
</script>

<template>
  <component :is="layout" v-if="auth.ready">
    <RouterView />
  </component>

  <div v-else class="flex min-h-screen items-center justify-center">
    <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
  </div>

  <ToastHost />
</template>