<script setup>
import { computed, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { errorMessage, validationErrors } from '@/lib/api'
import { useToast } from '@/composables/useToast'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const toast = useToast()
const role = computed(() => route.query.role === 'faculty' ? 'faculty' : route.query.role === 'administrator' ? 'administrator' : '')
const roleLabel = computed(() => role.value === 'faculty' ? 'Faculty' : 'Administrator')
const form = reactive({ email: '', password: '' })
const errors = ref({})
const loading = ref(false)

if (!role.value) router.replace({ name: 'login' })

async function submit() {
  if (!role.value) {
    router.replace({ name: 'login' })
    return
  }
  loading.value = true
  errors.value = {}
  try {
    const user = await auth.login({ ...form, role: role.value })
    toast.success(`Welcome back, ${user.first_name}.`)
    router.push(route.query.redirect ?? { name: 'dashboard' })
  } catch (error) {
    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) toast.error(errorMessage(error, 'Unable to sign in.'))
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <section class="mx-auto w-full max-w-sm">
    <button type="button" class="mb-7 inline-flex items-center gap-2 text-sm font-semibold text-primary-800 hover:text-primary-900" @click="router.push({ name: 'login' })">
      <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6" /></svg>
      Change account type
    </button>
    <div class="mb-7">
      <p class="text-sm font-semibold text-primary-800">{{ roleLabel }} account</p>
      <h1 class="mt-2 text-3xl font-bold text-ink">Welcome back!</h1>
      <p class="mt-2 text-sm leading-6 text-ink-muted">Sign in with your NVSU account to continue.</p>
    </div>
    <form class="flex flex-col gap-4" @submit.prevent="submit">
      <BaseInput v-model="form.email" label="University Email" type="email" placeholder="name@nvsu.edu.ph" :error="errors.email" required autocomplete="username" />
      <BaseInput v-model="form.password" label="Password" type="password" placeholder="Enter your password" :error="errors.password" required autocomplete="current-password" />
      <p v-if="errors.role" class="text-sm text-red-600">{{ errors.role }}</p>
      <BaseButton type="submit" :loading="loading" block class="mt-2 bg-primary-800! font-bold hover:bg-primary-900! active:bg-primary-900!">Sign in</BaseButton>
      <p class="pt-2 text-center text-xs leading-5 text-ink-muted">Your selected account type must match the role assigned to your NVSU account.</p>
    </form>
  </section>
</template>
