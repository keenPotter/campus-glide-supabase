import { defineStore } from 'pinia'
import api, { unwrap } from '@/lib/api'
import { supabase } from '@/lib/supabase'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    token: null,
    ready: false,
  }),

  getters: {
    isAuthenticated: (state) => Boolean(state.token && state.user),
    role: (state) => state.user?.role ?? null,
    isAdministrator: (state) => state.user?.role === 'administrator',
    isFaculty: (state) => state.user?.role === 'faculty',
    isStaff: (state) => state.user?.role === 'staff',
  },

  actions: {
    // Supabase keeps the real session. Passing null signs this tab out.
    setToken(token) {
      this.token = token
      if (!token) {
        supabase.auth.signOut({ scope: 'local' })
      }
    },

    async login(credentials) {
      const { data } = await api.post('/login', credentials)
      this.token = data.token
      this.user = data.user
      this.ready = true
      return this.user
    },

    async fetchUser() {
      const {
        data: { session },
      } = await supabase.auth.getSession()
      this.token = session?.access_token ?? null

      if (!this.token) {
        this.user = null
        this.ready = true
        return null
      }

      try {
        const response = await api.get('/user')
        this.user = unwrap(response)
      } catch {
        this.setToken(null)
        this.user = null
      } finally {
        this.ready = true
      }

      return this.user
    },

    async logout() {
      try {
        await api.post('/logout')
      } catch {
        // the session may already be invalid, so clear it here regardless
      }
      this.setToken(null)
      this.user = null
    },
  },
})