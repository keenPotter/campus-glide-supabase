<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useVehicleRequestStore } from '@/stores/vehicleRequests'
import { errorMessage, validationErrors } from '@/lib/api'
import { todayIso, toTimeInput } from '@/lib/format'
import { useToast } from '@/composables/useToast'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'

const store = useVehicleRequestStore()
const route = useRoute()
const router = useRouter()
const toast = useToast()

const isEdit = computed(() => Boolean(route.params.id))
const loading = ref(false)
const submitting = ref(false)
const errors = ref({})

// Status of the request when the page was opened.
// Editing an approved request needs a reason and a confirmation.
const originalStatus = ref('')
const confirmOpen = ref(false)
const needsReason = computed(() => isEdit.value && originalStatus.value === 'approved')

const form = reactive({
  destination: '',
  purpose: '',
  trip_date: todayIso(),
  trip_end_date: todayIso(),
  trip_type: 'inclusive',
  departure_time: '07:30',
  estimated_return_time: '17:00',
  passengers: '',
  number_of_passengers: 1,
  edit_reason: '',
})

const tripTypes = [
  { value: 'inclusive', label: 'Inclusive (Inside Nueva Vizcaya)' },
  { value: 'exclusive', label: 'Exclusive (Outside Nueva Vizcaya)' },
]

onMounted(async () => {
  if (!isEdit.value) return

  loading.value = true
  try {
    const request = await store.find(route.params.id)
    originalStatus.value = request.status
    Object.assign(form, {
      destination: request.destination ?? '',
      purpose: request.purpose ?? '',
      trip_date: request.trip_date ?? todayIso(),
      trip_end_date: request.trip_end_date ?? todayIso(),
      trip_type: request.trip_type ?? 'inclusive',
      departure_time: toTimeInput(request.departure_time),
      estimated_return_time: toTimeInput(request.return_time),
      passengers: request.passengers ?? '',
      number_of_passengers: request.number_of_passengers ?? 1,
    })
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to load this request.'))
    router.push({ name: 'requests.index' })
  } finally {
    loading.value = false
  }
})

// For an approved request: check the reason, then ask for confirmation before saving.
function submit() {
  errors.value = {}

  if (needsReason.value) {
    if (!form.edit_reason.trim()) {
      errors.value = { edit_reason: 'Please give a reason for editing this approved request.' }
      return
    }

    confirmOpen.value = true
    return
  }

  save()
}

async function save() {
  submitting.value = true
  errors.value = {}

  const payload = {
    ...form,
    number_of_passengers: Number(form.number_of_passengers),
  }

  if (needsReason.value) {
    payload.edit_reason = form.edit_reason.trim()
  } else {
    delete payload.edit_reason
  }

  try {
    if (isEdit.value) {
      await store.update(route.params.id, payload)
      toast.success(
        needsReason.value
          ? 'Request updated and sent back to the administrator for approval.'
          : 'Request updated.',
      )
      router.push({ name: 'requests.show', params: { id: route.params.id } })
    } else {
      const created = await store.create(payload)
      toast.success('Request submitted for approval.')
      router.push({ name: 'requests.show', params: { id: created.id } })
    }
  } catch (error) {
    confirmOpen.value = false
    errors.value = validationErrors(error)
    if (!Object.keys(errors.value).length) {
      toast.error(errorMessage(error, 'Unable to save this request.'))
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="mx-auto flex max-w-3xl flex-col gap-page">
    <div>
      <h1 class="text-page-title">{{ isEdit ? 'Edit request' : 'Request for use of vehicle' }}</h1>
      <p class="mt-0.5 text-small text-ink-muted">
        Please accomplish this form three (3) days before travel.
      </p>
    </div>

    <!-- Shown only when editing a request that was already approved. -->
    <div
      v-if="needsReason"
      class="rounded-card border-l-4 border-secondary bg-secondary-50 p-card text-small text-secondary-700"
    >
      <p class="font-medium">This request is already approved.</p>
      <p class="mt-1">
        If you save your changes, the vehicle and driver assigned to it will be released and the
        request will wait for the administrator's approval again.
      </p>
    </div>

    <form class="flex flex-col gap-page" @submit.prevent="submit">
      <BaseCard title="Trip details">
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="sm:col-span-2">
            <BaseInput
              v-model="form.destination"
              label="Destination / place"
              placeholder="e.g. Tuguegarao City"
              :error="errors.destination"
              required
            />
          </div>

          <div class="sm:col-span-2">
            <BaseInput
              v-model="form.purpose"
              label="Purpose"
              placeholder="e.g. To attend the CVATPA officers meeting"
              :error="errors.purpose"
              required
            />
          </div>

          <BaseInput
            v-model="form.trip_date"
            label="Date of travel"
            type="date"
            :min="todayIso()"
            :error="errors.trip_date"
            required
          />

          <BaseInput
            v-model="form.trip_end_date"
            label="End date of travel"
            type="date"
            :min="form.trip_date"
            :error="errors.trip_end_date"
            required
          />

          <div class="sm:col-span-2">
            <BaseSelect
              v-model="form.trip_type"
              label="Days of travel"
              :options="tripTypes"
              :error="errors.trip_type"
              required
            />
          </div>

          <BaseInput
            v-model="form.departure_time"
            label="Time of departure"
            type="time"
            :error="errors.departure_time"
            required
          />

          <BaseInput
            v-model="form.estimated_return_time"
            label="Estimated return time"
            type="time"
            :error="errors.estimated_return_time"
            required
          />
        </div>
      </BaseCard>

      <BaseCard title="Passengers">
        <div class="grid gap-4 sm:grid-cols-3">
          <div class="sm:col-span-2">
            <BaseInput
              v-model="form.passengers"
              label="Authorized passenger(s)"
              placeholder="e.g. All fund administrators"
              :error="errors.passengers"
              required
            />
          </div>

          <BaseInput
            v-model="form.number_of_passengers"
            label="Number of passengers"
            type="number"
            min="1"
            :error="errors.number_of_passengers"
            required
          />
        </div>
      </BaseCard>

      <BaseCard v-if="needsReason" title="Reason for editing">
        <BaseTextarea
          v-model="form.edit_reason"
          label="Why are you changing this approved request?"
          placeholder="e.g. The meeting was moved to a later date."
          :error="errors.edit_reason"
          required
        />
      </BaseCard>

      <div class="flex justify-end gap-3">
        <BaseButton variant="outline" @click="router.back()">Cancel</BaseButton>
        <BaseButton type="submit" :loading="(submitting && !confirmOpen) || loading">
          {{ isEdit ? 'Save changes' : 'Submit request' }}
        </BaseButton>
      </div>
    </form>

    <!-- Confirmation before changing an approved request -->
    <BaseModal
      :open="confirmOpen"
      title="Change an approved request?"
      subtitle="Please read before you continue"
      @close="confirmOpen = false"
    >
      <p class="text-body">If you continue:</p>
      <ul class="mt-2 list-disc space-y-1 pl-5 text-body">
        <li>The vehicle and driver assigned to this request will be released.</li>
        <li>The request becomes a new pending request.</li>
        <li>The administrator must approve it again before a vehicle and driver are assigned.</li>
      </ul>

      <template #footer>
        <BaseButton variant="outline" :disabled="submitting" @click="confirmOpen = false">
          Go back
        </BaseButton>
        <BaseButton variant="danger" :loading="submitting" @click="save">
          Yes, save changes
        </BaseButton>
      </template>
    </BaseModal>
  </div>
</template>