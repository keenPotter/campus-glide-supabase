<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import nvsuLogo from '@/assets/nvsu-logo.png'

const router = useRouter()
const selectedRole = ref('')
const roles = [
  { value: 'administrator', title: 'Administrator', description: 'Manage fleet operations and campus transportation.', icon: 'M12 3 4.5 7v5c0 4.5 3.2 7.7 7.5 9 4.3-1.3 7.5-4.5 7.5-9V7L12 3Zm-3 9 2 2 4-4' },
  { value: 'faculty', title: 'Faculty', description: 'Request and follow your campus transportation.', icon: 'M12 3 2.5 8 12 13l9.5-5L12 3Zm-6 8.2V16l6 3 6-3v-4.8' },
]

function continueToLogin() {
  if (!selectedRole.value) return
  router.push({ name: 'login.form', query: { role: selectedRole.value } })
}
</script>

<template>
  <section class="mx-auto w-full max-w-lg">
    <div class="mb-8 flex flex-col items-center text-center">
      <img :src="nvsuLogo" alt="Nueva Vizcaya State University seal" class="mb-4 h-20 w-20 object-contain" />
      <p class="text-xs font-bold uppercase tracking-[0.18em] text-primary-800">Nueva Vizcaya State University</p>
      <h1 class="mt-3 text-3xl font-bold text-ink">Welcome to CampusGlide</h1>
      <p class="mt-2 max-w-md text-sm leading-6 text-ink-muted">Choose your account type to continue to the fleet management system.</p>
    </div>

    <div class="grid gap-4 sm:grid-cols-2">
      <button
        v-for="role in roles"
        :key="role.value"
        type="button"
        class="group rounded-2xl border-2 p-5 text-left transition duration-200 hover:-translate-y-0.5 hover:border-primary-500 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400"
        :class="selectedRole === role.value ? 'border-primary-600 bg-primary-50 shadow-sm' : 'border-slate-200 bg-white'"
        :aria-pressed="selectedRole === role.value"
        @click="selectedRole = role.value"
      >
        <span class="mb-4 flex h-12 w-12 items-center justify-center rounded-xl" :class="selectedRole === role.value ? 'bg-primary-700 text-white' : 'bg-primary-50 text-primary-800'">
          <svg class="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path :d="role.icon" /></svg>
        </span>
        <span class="block text-base font-bold text-ink">{{ role.title }}</span>
        <span class="mt-2 block text-sm leading-5 text-ink-muted">{{ role.description }}</span>
        <span class="mt-4 flex items-center gap-2 text-sm font-semibold" :class="selectedRole === role.value ? 'text-primary-800' : 'text-slate-500'">
          <span class="flex h-4 w-4 items-center justify-center rounded-full border" :class="selectedRole === role.value ? 'border-primary-700 bg-primary-700' : 'border-slate-300'">
            <span v-if="selectedRole === role.value" class="h-1.5 w-1.5 rounded-full bg-white" />
          </span>
          {{ selectedRole === role.value ? 'Selected' : 'Select account' }}
        </span>
      </button>
    </div>

    <button type="button" class="mt-6 flex h-12 w-full items-center justify-center rounded-xl bg-primary-800 px-5 font-bold text-white transition hover:bg-primary-900 disabled:cursor-not-allowed disabled:opacity-40" :disabled="!selectedRole" @click="continueToLogin">
      Continue
      <svg class="ml-2 h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M12 5l7 7-7 7" /></svg>
    </button>
    <p class="mt-5 text-center text-xs text-ink-muted">Need an account? Contact a CampusGlide administrator.</p>
  </section>
</template>
