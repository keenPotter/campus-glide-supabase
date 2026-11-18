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
const role = computed(() => ['faculty', 'administrator', 'staff'].includes(route.query.role) ? route.query.role : '')
const roleLabel = computed(() => role.value === 'faculty' ? 'User' : role.value === 'staff' ? 'Staff' : 'Admin')
const form = reactive({ email: '', password: '' })
const errors = ref({})
const loading = ref(false)
const capsLockActive = ref(false)

if (!role.value) router.replace({ name: 'login' })

function focusPassword(event) {
  event.target.form?.elements.namedItem('cg-login-password')?.focus()
}

function updateCapsLock(event) {
  capsLockActive.value = event.getModifierState('CapsLock')
}

async function submit() {
  if (!role.value) {
    router.replace({ name: 'login' })
    return
  }
  if (capsLockActive.value) {
    toast.error('Caps Lock is on. Turn it off before signing in.')
    return
  }
  loading.value = true
  errors.value = {}
  try {
    await auth.login({ ...form, role: role.value })
    toast.success('Welcome')
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
      <h1 class="mt-2 text-3xl font-bold text-ink">Welcome</h1>
      <p class="mt-2 text-sm leading-6 text-ink-muted">Sign in with your NVSU account to continue.</p>
    </div>
    <form class="flex flex-col gap-4" autocomplete="off" @submit.prevent="submit" @keydown.capture="updateCapsLock" @keyup.capture="updateCapsLock">
      <BaseInput v-model="form.email" id="cg-login-username" label="Username (University Email)" type="email" placeholder="name@nvsu.edu.ph" name="cg-login-username" :error="errors.email" required autocomplete="off" @keydown.enter.prevent="focusPassword" />
      <BaseInput v-model="form.password" id="cg-login-password" label="Password" type="password" placeholder="Enter your password" name="cg-login-password" :error="errors.password" required autocomplete="new-password" :show-password-toggle="true" />
      <p v-if="capsLockActive" role="alert" class="rounded-lg bg-amber-50 p-3 text-sm text-amber-800">Caps Lock is on. Turn it off before signing in.</p>
      <p v-if="errors.role" class="text-sm text-red-600">{{ errors.role }}</p>
      <BaseButton type="submit" :loading="loading" block class="mt-2 bg-primary-800! font-bold hover:bg-primary-900! active:bg-primary-900!">Sign in</BaseButton>
      <p class="pt-2 text-center text-xs leading-5 text-ink-muted">Your selected account type must match the role assigned to your NVSU account.</p>
    </form>
  </section>
</template>
