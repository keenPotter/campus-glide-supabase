<script setup>
import { onMounted, ref, watch } from 'vue'
import api, { errorMessage } from '@/lib/api'
import { formatDateTime } from '@/lib/format'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import PaginationBar from '@/components/ui/PaginationBar.vue'
import RefreshButton from '@/components/ui/RefreshButton.vue'
import LoadError from '@/components/ui/LoadError.vue'

const logs = ref([])
const paginationMeta = ref(null)
const loading = ref(true)
const loadError = ref('')
const page = ref(1)
const actionFilter = ref('')
const userEmail = ref('')

const actionOptions = [
  'LOGIN',
  'LOGOUT',
  'VIEW_TRIP_DETAILS',
  'CREATE_USER',
  'UPDATE_USER',
  'DEACTIVATE_USER',
  'RESTORE_USER',
  'TRANSFER_ADMINISTRATOR',
  'CREATE_VEHICLE_REQUEST',
  'EDIT_VEHICLE_REQUEST',
  'UPDATE_VEHICLE_REQUEST_STATUS',
  'APPROVE_AND_ALLOCATE_REQUEST',
  'UPDATE_ALLOCATION',
  'RESCHEDULE_ALLOCATION',
  'CREATE_RESCHEDULE_REQUEST',
  'APPROVE_RESCHEDULE_REQUEST',
  'DISAPPROVE_RESCHEDULE_REQUEST',
  'SEND_TRIP_REQUEST',
  'CREATE_DRIVER',
  'CREATE_VEHICLE',
  'CREATE_MAINTENANCE',
  'UPDATE_MAINTENANCE',
  'COMPLETE_MAINTENANCE',
  'CREATE_POST_TRAVEL_REPORT',
  'UPDATE_POST_TRAVEL_REPORT',
  'CREATE_FUEL_USAGE_RECORD',
  'UPDATE_FUEL_USAGE_RECORD',
  'CREATE_PREVENTIVE_MAINTENANCE_CHECKLIST',
  'UPDATE_PREVENTIVE_MAINTENANCE_CHECKLIST',
].map((action) => ({
  value: action,
  label: action.replaceAll('_', ' ').toLowerCase().replace(/\b\w/g, (letter) => letter.toUpperCase()),
}))

async function loadLogs() {
  loading.value = true
  loadError.value = ''

  try {
    const response = await api.get('/audit-logs', {
      params: {
        page: page.value,
        per_page: 20,
        action: actionFilter.value || undefined,
        user_email: userEmail.value || undefined,
      },
    })
    logs.value = response.data?.data ?? []
    paginationMeta.value = response.data?.meta ?? null
  } catch (error) {
    loadError.value = errorMessage(error, 'Unable to load audit logs.')
  } finally {
    loading.value = false
  }
}

function changePage(value) {
  page.value = value
  loadLogs()
}

function targetDescription(log) {
  const table = log.target_table?.replaceAll('_', ' ')
  return [table, log.target_id ? `#${log.target_id}` : ''].filter(Boolean).join(' ')
}

watch([actionFilter, userEmail], (_, __, onCleanup) => {
  page.value = 1
  const timeout = setTimeout(loadLogs, 250)
  onCleanup(() => clearTimeout(timeout))
})

onMounted(loadLogs)
</script>

<template>
  <div class="flex flex-col gap-page">
    <div class="page-header">
      <div class="page-header-copy">
        <h1 class="text-page-title">Audit log</h1>
        <p class="mt-1 text-small text-ink-muted">Append-only history of important account and fleet changes.</p>
      </div>
      <div class="page-actions">
        <RefreshButton :loading="loading" label="Refresh audit log" @click="loadLogs" />
      </div>
    </div>

    <BaseCard>
      <div class="mb-4 grid gap-3 sm:grid-cols-2">
        <BaseSelect
          v-model="actionFilter"
          label="Action type"
          :options="actionOptions"
          placeholder="All actions"
          allow-empty
        />
        <BaseInput
          v-model="userEmail"
          label="User email"
          type="search"
          placeholder="Search by email..."
        />
      </div>

      <div v-if="loading" class="flex justify-center p-12" aria-label="Loading audit logs">
        <div class="h-8 w-8 animate-spin rounded-full border-2 border-line border-t-primary" />
      </div>
      <LoadError v-else-if="loadError" :message="loadError" @retry="loadLogs" />
      <div v-else-if="!logs.length" class="py-8 text-center text-ink-muted">No audit records found.</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full min-w-[760px] text-left text-small">
          <thead class="border-b border-line text-xs uppercase tracking-wide text-ink-muted">
            <tr>
              <th scope="col" class="px-3 py-3">Timestamp</th>
              <th scope="col" class="px-3 py-3">User</th>
              <th scope="col" class="px-3 py-3">Action type</th>
              <th scope="col" class="px-3 py-3">Target / details</th>
              <th scope="col" class="px-3 py-3">IP address</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-line">
            <tr v-for="log in logs" :key="log.id" class="align-top">
              <td class="whitespace-nowrap px-3 py-3">{{ formatDateTime(log.created_at) }}</td>
              <td class="px-3 py-3">
                <p class="font-medium">{{ log.user?.name || 'Unavailable account' }}</p>
                <p class="mt-0.5 break-all text-xs text-ink-muted">{{ log.user?.email || 'No associated email' }}</p>
              </td>
              <td class="px-3 py-3">
                <span class="inline-flex rounded-full bg-primary-50 px-2.5 py-1 text-xs font-semibold text-primary-700">
                  {{ log.action.replaceAll('_', ' ') }}
                </span>
              </td>
              <td class="px-3 py-3 capitalize">{{ targetDescription(log) || '—' }}</td>
              <td class="whitespace-nowrap px-3 py-3 font-mono text-xs">{{ log.ip_address || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <PaginationBar v-if="!loading" :meta="paginationMeta" @change="changePage" />
    </BaseCard>
  </div>
</template>
