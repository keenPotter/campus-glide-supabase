<script setup>
import { useAuthStore } from '@/stores/auth'
import AdminAllocations from '@/components/allocations/AdminAllocations.vue'
import FacultyAllocations from '@/components/allocations/FacultyAllocations.vue'

const auth = useAuthStore()
</script>

<template>
  <!-- Administrators and staff use the same allocation page. -->
  <AdminAllocations v-if="auth.isAdministrator || auth.isStaff" />
  <FacultyAllocations v-else />
</template>