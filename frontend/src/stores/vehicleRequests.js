import { defineStore } from 'pinia'
import api, { unwrap } from '@/lib/api'
import { todayIso } from '@/lib/format'
import { useNotificationStore } from '@/stores/notifications'

export const useVehicleRequestStore = defineStore('vehicleRequests', {
  state: () => ({
    items: [],
    current: null,
    meta: null,
    loading: false,
    filters: {
      status: '',
      trip_type: '',
      page: 1,
    },
  }),

  // Removed the `countByStatus` getter: it counted only the current page,
  // so the dashboard numbers were wrong. See fetchSummary() below.

  actions: {
    async fetch(overrides = {}) {
      this.loading = true
      this.filters = { ...this.filters, ...overrides }

      try {
        const { data } = await api.get('/vehicle-requests', {
          params: {
            status: this.filters.status || undefined,
            trip_type: this.filters.trip_type || undefined,
            page: this.filters.page,
          },
        })

        // The backend filters by status and trip_type, so nothing is filtered here.
        this.items = data.data ?? []
        this.meta = data.meta ?? null
        return this.items
      } finally {
        this.loading = false
      }
    },

    async find(id) {
      this.loading = true
      try {
        const response = await api.get(`/vehicle-requests/${id}`)
        this.current = unwrap(response)
        return this.current
      } finally {
        this.loading = false
      }
    },

    async create(payload) {
      const response = await api.post('/vehicle-requests', payload)
      return unwrap(response)
    },

    async update(id, payload) {
      const response = await api.put(`/vehicle-requests/${id}/edit`, payload)
      return unwrap(response)
    },

    // status is 'approved' or 'disapproved'. 'remarks' is required when disapproving.
    async updateStatus(id, payload) {
      const response = await api.patch(`/vehicle-requests/${id}/status`, payload)
      // Update the sidebar numbers right after a decision.
      useNotificationStore().refresh()
      return unwrap(response)
    },

    // Numbers and upcoming trips for the dashboard.
    // Counts come from meta.total, so they include every page.
    // This does not touch `items` or `filters`, which belong to the list page.
    async fetchSummary() {
      const [pending, approved, disapproved] = await Promise.all(
        ['pending', 'approved', 'disapproved'].map((status) =>
          api.get('/vehicle-requests', { params: { status } }),
        ),
      )

      const total = (response) => response.data?.meta?.total ?? response.data?.data?.length ?? 0
      const today = todayIso()

      // Upcoming = pending or approved requests whose trip has not ended yet, soonest first.
      // Only the newest page of each status is checked.
      const upcoming = [...(pending.data?.data ?? []), ...(approved.data?.data ?? [])]
        .filter((item) => (item.trip_end_date || item.trip_date) >= today)
        .sort((a, b) => String(a.trip_date).localeCompare(String(b.trip_date)))
        .slice(0, 5)

      return {
        counts: {
          pending: total(pending),
          approved: total(approved),
          disapproved: total(disapproved),
        },
        upcoming,
      }
    },
  },
})