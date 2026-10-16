<script setup>
import { onMounted, ref } from 'vue'
import api, { errorMessage, unwrap } from '@/lib/api'
import BaseCard from '@/components/ui/BaseCard.vue'
import LoadError from '@/components/ui/LoadError.vue'
import PreventiveMaintenanceSection from '@/components/maintenance/PreventiveMaintenanceSection.vue'

const vehicles = ref([])
const loading = ref(true)
const loadError = ref('')

async function loadVehicles() {
  loading.value = true
  loadError.value = ''

  try {
    const response = await api.get('/vehicles')
    const payload = unwrap(response)
    vehicles.value = Array.isArray(payload) ? payload : []
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load vehicles.')
  } finally {
    loading.value = false
  }
}

onMounted(loadVehicles)
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-page-title">Preventive Maintenance</h1>
      <p class="mt-1 text-small text-ink-muted">
        Choose a vehicle to assess, then print its monthly preventive maintenance checklist.
      </p>
    </div>

    <BaseCard v-if="loading" title="Loading vehicles">
      <p class="text-small text-ink-muted">Please wait...</p>
    </BaseCard>

    <LoadError v-else-if="loadError" :message="loadError" @retry="loadVehicles" />

    <PreventiveMaintenanceSection v-else :vehicles="vehicles" />
  </div>
</template>