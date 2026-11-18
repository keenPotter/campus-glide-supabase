import { defineStore } from 'pinia'
import api from '@/lib/api'
import { useAuthStore } from '@/stores/auth'

// A refresh that is already running is reused.
// If two parts of the app ask for the numbers at the same time, only one request is sent.
let running = null

export const useNotificationStore = defineStore('notifications', {
  state: () => ({
    pendingRequests: 0,
    openMaintenance: 0,
    // Pending or approved requests that do not yet have a trip.
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
    // One small request gets all four numbers. The sidebar numbers are shown to administrators only.
    refresh() {
      if (!useAuthStore().isAdministrator) return Promise.resolve()
      if (running) return running

      running = api
        .get('/notifications/summary')
        .then(({ data }) => {
          const summary = data?.data ?? {}
          this.pendingRequests = summary.pending_requests ?? 0
          this.openMaintenance = summary.open_maintenance ?? 0
          this.needsAllocation = summary.needs_allocation ?? 0
          this.pendingDateChanges = summary.pending_date_changes ?? 0
        })
        // If the request fails, the old numbers stay on the screen.
        .catch(() => {})
        .finally(() => {
          running = null
        })

      return running
    },

    reset() {
      this.pendingRequests = 0
      this.openMaintenance = 0
      this.needsAllocation = 0
      this.pendingDateChanges = 0
    },
  },
})