import { defineStore } from 'pinia'
import api, { TOKEN_KEY, unwrap } from '@/lib/api'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    token: localStorage.getItem(TOKEN_KEY),
    ready: false,
  }),

  getters: {
    isAuthenticated: (state) => Boolean(state.token && state.user),
    role: (state) => state.user?.role ?? null,
    isAdministrator: (state) => state.user?.role === 'administrator',
    isFaculty: (state) => state.user?.role === 'faculty',
  },

  actions: {
    setToken(token) {
      this.token = token
      if (token) {
        localStorage.setItem(TOKEN_KEY, token)
      } else {
        localStorage.removeItem(TOKEN_KEY)
      }
    },

    async login(credentials) {
      const { data } = await api.post('/login', credentials)
      this.setToken(data.token)
      this.user = data.user
      this.ready = true
      return this.user
    },

    async fetchUser() {
      if (!this.token) {
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
        // token may already be invalid — clear locally regardless
      }
      this.setToken(null)
      this.user = null
    },
  },
})