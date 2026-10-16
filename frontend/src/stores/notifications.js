import { defineStore } from 'pinia'
import api from '@/lib/api'

// Maintenance records that still need the admin's attention.
const OPEN_MAINTENANCE = ['in_progress']

export const useNotificationStore = defineStore('notifications', {
  state: () => ({
    pendingRequests: 0,
    openMaintenance: 0,
    // Approved requests that still need a vehicle and driver.
    needsAllocation: 0,
    // Faculty requests to change the date of a trip.
    pendingDateChanges: 0,
  }),

  getters: {
    allocationAttention: (state) => state.needsAllocation + state.pendingDateChanges,
    total: (state) =>
      state.pendingRequests +
      state.openMaintenance +
      state.needsAllocation +
      state.pendingDateChanges,
  },

  actions: {
    async refresh() {
      const [requests, maintenance, approved, dateChanges] = await Promise.allSettled([
        api.get('/vehicle-requests', { params: { status: 'pending' } }),
        api.get('/maintenance-logs'),
        api.get('/vehicle-requests/approved'),
        api.get('/reschedule-requests', { params: { status: 'pending' } }),
      ])

      if (requests.status === 'fulfilled') {
        const body = requests.value.data
        // meta.total counts every page, not just the first one.
        this.pendingRequests = body?.meta?.total ?? body?.data?.length ?? 0
      }

      if (maintenance.status === 'fulfilled') {
        const body = maintenance.value.data
        const logs = Array.isArray(body) ? body : (body?.data ?? [])
        this.openMaintenance = logs.filter((log) => OPEN_MAINTENANCE.includes(log.status)).length
      }

      // This endpoint is not paginated, so the number of rows is the total.
      if (approved.status === 'fulfilled') {
        this.needsAllocation = approved.value.data?.data?.length ?? 0
      }

      if (dateChanges.status === 'fulfilled') {
        this.pendingDateChanges = dateChanges.value.data?.data?.length ?? 0
      }
    },

    reset() {
      this.pendingRequests = 0
      this.openMaintenance = 0
      this.needsAllocation = 0
      this.pendingDateChanges = 0
    },
  },
})