<script setup>
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import { TRIP_TYPE_DESCRIPTIONS } from '@/lib/format'

defineProps({
  form: { type: Object, required: true },
  errors: { type: Object, default: () => ({}) },
})

const tripTypes = [
  { value: 'inclusive', label: TRIP_TYPE_DESCRIPTIONS.inclusive },
  { value: 'exclusive', label: TRIP_TYPE_DESCRIPTIONS.exclusive },
]
</script>

<template>
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
        placeholder="e.g. Attend a meeting"
        :error="errors.purpose"
        required
      />
    </div>

    <BaseInput
      v-model="form.trip_date"
      label="Date of travel"
      type="date"
      :min="form.min_trip_date"
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

    <BaseSelect
      v-model="form.trip_type"
      label="Trip type"
      :options="tripTypes"
      placeholder="Select trip type"
      :error="errors.trip_type"
      required
    />

    <BaseInput
      v-model="form.number_of_passengers"
      label="Number of passengers"
      type="number"
      min="1"
      :error="errors.number_of_passengers"
      required
    />

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

    <div class="sm:col-span-2">
      <BaseInput
        v-model="form.passengers"
        label="Authorized passenger(s)"
        placeholder="e.g. All fund administrators"
        :error="errors.passengers"
        required
      />
    </div>
  </div>
</template>