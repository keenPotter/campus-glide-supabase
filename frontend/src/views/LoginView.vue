<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import nvsuLogo from '@/assets/nvsu-logo.png'

const router = useRouter()
const route = useRoute()
const selectedRole = ref('')
const roles = [
  { value: 'administrator', title: 'Admin', description: 'Manage fleet operations and campus transportation.', icon: 'M12 3 4.5 7v5c0 4.5 3.2 7.7 7.5 9 4.3-1.3 7.5-4.5 7.5-9V7L12 3Zm-3 9 2 2 4-4' },
  { value: 'staff', title: 'Staff', description: 'View dashboard, allocations, and trip schedules.', icon: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z' },
  { value: 'faculty', title: 'User', description: 'Request and follow your campus transportation.', icon: 'M12 3 2.5 8 12 13l9.5-5L12 3Zm-6 8.2V16l6 3 6-3v-4.8' },
]

function chooseRole(role) {
  selectedRole.value = role
  // Selecting an account type immediately opens the original sign-in page.
  router.push({ name: 'login.form', query: { ...route.query, role } })
}
</script>

<template>
  <section class="mx-auto w-full max-w-3xl">
    <div class="mb-8 flex flex-col items-center text-center">
      <img :src="nvsuLogo" alt="Nueva Vizcaya State University seal" class="mb-4 h-20 w-20 object-contain" />
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-primary-800">Nueva Vizcaya State University</p>
      <h1 class="mt-3 text-3xl font-bold text-ink">Welcome to CampusGlide</h1>
      <p class="mt-2 max-w-md text-sm leading-6 text-ink-muted">Choose your account type to sign in.</p>
    </div>

    <div class="grid gap-4 sm:grid-cols-3">
      <button
        v-for="role in roles"
        :key="role.value"
        type="button"
        class="group rounded-2xl border-2 p-5 text-left transition duration-200 hover:-translate-y-0.5 hover:border-primary-500 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400"
        :class="selectedRole === role.value ? 'border-primary-600 bg-primary-50 shadow-sm' : 'border-slate-200 bg-white'"
        :aria-pressed="selectedRole === role.value"
        @click="chooseRole(role.value)"
      >
        <span class="mb-4 flex h-12 w-12 items-center justify-center rounded-xl" :class="selectedRole === role.value ? 'bg-primary-700 text-white' : 'bg-primary-50 text-primary-800'">
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path :d="role.icon" /></svg>
        </span>
        <span class="block text-base font-bold text-ink">{{ role.title }}</span>
        <span class="mt-2 block text-sm leading-5 text-ink-muted">{{ role.description }}</span>
      </button>
    </div>

    <p class="mt-5 text-center text-xs text-ink-muted">Need an account? Contact a CampusGlide administrator.</p>
  </section>
</template>
