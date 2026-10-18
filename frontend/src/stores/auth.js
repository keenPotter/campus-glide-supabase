import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabase'
import { httpError } from '@/lib/api'

// The profile row (role, name, is_active) of an auth user.
async function loadProfile(userId) {
  const { data, error } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle()
  if (error) throw error
  return data
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    ready: false,
  }),

  getters: {
    isAuthenticated: (state) => Boolean(state.user),
    role: (state) => state.user?.role ?? null,
    isAdministrator: (state) => state.user?.role === 'administrator',
    isFaculty: (state) => state.user?.role === 'faculty',
    isStaff: (state) => state.user?.role === 'staff',
  },

  actions: {
    // The session (tokens) is kept by supabase-js. The store keeps the profile.
    async login({ email, password, role }) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: String(email ?? '').trim(),
        password,
      })

      if (error) {
        // A disabled account (for example, one scheduled for deletion) cannot sign in.
        if (error.code === 'user_banned') {
          const message = 'This account has been deactivated.'
          throw httpError(422, message, { email: [message] })
        }
        if (error.code === 'invalid_credentials' || error.status === 400) {
          const message = 'These credentials do not match our records.'
          throw httpError(422, message, { email: [message] })
        }
        // Network or server problem: the login page shows its own message.
        throw new Error(error.message)
      }

      let profile = null
      try {
        profile = await loadProfile(data.user.id)
      } catch {
        // handled below
      }

      if (!profile || !profile.is_active) {
        await supabase.auth.signOut()
        const message = 'This account is not active. Please contact an administrator.'
        throw httpError(422, message, { email: [message] })
      }

      // The account type chosen on the login page must match the role of the account.
      if (role && profile.role !== role) {
        await supabase.auth.signOut()
        const message = 'The selected account type does not match your account.'
        throw httpError(422, message, { role: [message] })
      }

      this.user = profile
      this.ready = true
      return this.user
    },

    async fetchUser() {
      try {
        const { data } = await supabase.auth.getSession()

        if (!data.session) {
          this.user = null
          return null
        }

        const profile = await loadProfile(data.session.user.id)

        if (!profile || !profile.is_active) {
          await supabase.auth.signOut()
          this.user = null
        } else {
          this.user = profile
        }
      } catch {
        this.user = null
      } finally {
        this.ready = true
      }

      return this.user
    },

    async logout() {
      try {
        await supabase.auth.signOut()
      } catch {
        // the session may already be invalid: clear locally regardless
      }
      this.user = null
    },
  },
})