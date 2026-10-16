<script setup>
import { reactive, ref } from 'vue'
import api, { errorMessage, validationErrors } from '@/lib/api'
import { useToast } from '@/composables/useToast'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'

const toast = useToast()

const roleOptions = [
  { value: 'administrator', label: 'Administrator' },
  { value: 'faculty', label: 'Faculty' },
]

function emptyForm() {
  return {
    first_name: '',
    last_name: '',
    email: '',
    position: '',
    phone_number: '',
    password: '',
    password_confirmation: '',
    role: '',
  }
}

const form = reactive(emptyForm())
const errors = ref({})
const notAllowed = ref(false)
const loading = ref(false)

async function submit() {
  loading.value = true
  errors.value = {}
  notAllowed.value = false

  try {
    // The admin's Bearer token is added automatically by the api.js request interceptor.
    await api.post('/register', { ...form })
    toast.success('User created successfully.')
    Object.assign(form, emptyForm())
  } catch (error) {
    const status = error?.response?.status

    // 401 (not logged in) is handled in api.js: it clears the token and goes to /login.
    if (status === 403) {
      notAllowed.value = true
      return
    }

    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      toast.error(errorMessage(error, 'Unable to create the user.'))
    }
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="mx-auto flex max-w-3xl flex-col gap-page">
    <div>
      <h1 class="text-page-title">Create user</h1>
      <p class="mt-0.5 text-small text-ink-muted">
        Add a new administrator or faculty account.
      </p>
    </div>

    <div
      v-if="notAllowed"
      class="rounded-card border border-red-200 bg-red-50 p-card text-small text-red-800"
    >
      <p class="font-medium">Not allowed</p>
      <p class="mt-1">You do not have permission to create users.</p>
    </div>

    <form class="flex flex-col gap-page" @submit.prevent="submit">
      <BaseCard title="User details">
        <div class="grid gap-4 sm:grid-cols-2">
          <BaseInput
            v-model="form.first_name"
            label="First name"
            placeholder="Juan"
            :error="errors.first_name"
            required
          />

          <BaseInput
            v-model="form.last_name"
            label="Last name"
            placeholder="Dela Cruz"
            :error="errors.last_name"
            required
          />

          <div class="sm:col-span-2">
            <BaseInput
              v-model="form.email"
              label="Email"
              type="email"
              :error="errors.email"
              required
            />
          </div>

          <!-- Added: the backend accepts these since Module 3. The position is printed on the request form. -->
          <BaseInput
            v-model="form.position"
            label="Position / designation"
            placeholder="e.g. Instructor III"
            hint="Printed on the vehicle request form."
            :error="errors.position"
          />

          <BaseInput
            v-model="form.phone_number"
            label="Phone number"
            type="tel"
            placeholder="0917-123-4567"
            :error="errors.phone_number"
          />

          <div class="sm:col-span-2">
            <BaseSelect
              v-model="form.role"
              label="Role"
              :options="roleOptions"
              :error="errors.role"
              required
            />
          </div>

          <BaseInput
            v-model="form.password"
            label="Password"
            type="password"
            hint="At least 8 characters."
            :error="errors.password"
            required
          />

          <BaseInput
            v-model="form.password_confirmation"
            label="Confirm password"
            type="password"
            :error="errors.password_confirmation"
            required
          />
        </div>
      </BaseCard>

      <div class="flex justify-end">
        <BaseButton type="submit" :loading="loading">Create user</BaseButton>
      </div>
    </form>
  </div>
</template>