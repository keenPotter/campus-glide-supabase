<script setup>
import { useAuthStore } from '@/stores/auth'
import AdminAllocations from '@/components/allocations/AdminAllocations.vue'
import FacultyAllocations from '@/components/allocations/FacultyAllocations.vue'

// Administrators manage allocations. Faculty see their own.
const auth = useAuthStore()
</script>

<template>
  <AdminAllocations v-if="auth.isAdministrator" />
  <FacultyAllocations v-else />
</template>