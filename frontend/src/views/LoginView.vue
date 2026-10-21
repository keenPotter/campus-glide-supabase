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
    <div class="mb-5 flex flex-col items-center text-center sm:mb-8">
      <img :src="nvsuLogo" alt="Nueva Vizcaya State University seal" class="mb-2 h-14 w-14 object-contain sm:mb-4 sm:h-20 sm:w-20" />
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-primary-800">Nueva Vizcaya State University</p>
      <h1 class="mt-2 text-2xl font-bold text-ink sm:mt-3 sm:text-3xl">Welcome to CampusGlide</h1>
      <p class="mt-1 max-w-md text-sm leading-5 text-ink-muted sm:mt-2 sm:leading-6">Choose your account type to sign in.</p>
    </div>

    <div class="grid gap-2 sm:grid-cols-3 sm:gap-4">
      <button
        v-for="role in roles"
        :key="role.value"
        type="button"
        class="group flex items-center gap-3 rounded-2xl border-2 p-3 text-left transition duration-200 hover:-translate-y-0.5 hover:border-primary-500 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400 sm:block sm:p-5"
        :class="selectedRole === role.value ? 'border-primary-600 bg-primary-50 shadow-sm' : 'border-slate-200 bg-white'"
        :aria-pressed="selectedRole === role.value"
        @click="chooseRole(role.value)"
      >
        <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl sm:mb-4 sm:h-12 sm:w-12" :class="selectedRole === role.value ? 'bg-primary-700 text-white' : 'bg-primary-50 text-primary-800'">
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path :d="role.icon" /></svg>
        </span>
        <span class="block min-w-0">
          <span class="block text-base font-bold text-ink">{{ role.title }}</span>
          <span class="mt-1 block text-sm leading-5 text-ink-muted sm:mt-2">{{ role.description }}</span>
        </span>
      </button>
    </div>

    <p class="mt-3 text-center text-xs text-ink-muted sm:mt-5">Need an account? Contact a CampusGlide administrator.</p>
  </section>
</template>