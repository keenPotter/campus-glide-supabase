import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !key) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY. See frontend/.env.example.')
}

// A login lasts 8 hours (the same as the Laravel version).
export const SESSION_START_KEY = 'cg_session_started'
export const SESSION_MAX_MS = 8 * 60 * 60 * 1000

// The session is kept in sessionStorage, like the Laravel token:
// every browser tab has its own login, and closing the tab ends it.
// supabase-js still refreshes the access token on its own while the tab is open.
export const supabase = createClient(url, key, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
    storage: window.sessionStorage,
  },
})

/** Remembers when this tab signed in. */
export function markSessionStart() {
  try {
    sessionStorage.setItem(SESSION_START_KEY, String(Date.now()))
  } catch {
    // storage is not available: the server limit still applies
  }
}

/** True when this tab signed in more than 8 hours ago. */
export function sessionExpired() {
  try {
    const started = Number(sessionStorage.getItem(SESSION_START_KEY))
    return Boolean(started) && Date.now() - started >= SESSION_MAX_MS
  } catch {
    return false
  }
}

/**
 * Signs out THIS tab only. The default signOut() ends every session of the user
 * on every device. The Laravel logout deleted only the current token, so this matches it.
 */
export function signOutLocal() {
  return supabase.auth.signOut({ scope: 'local' })
}

// Forget the start time whenever the session ends (sign-out, expiry or a revoked session).
supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_OUT') {
    try {
      sessionStorage.removeItem(SESSION_START_KEY)
    } catch {
      // ignore
    }
  }
})