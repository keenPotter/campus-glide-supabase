import { createClient } from '@supabase/supabase-js'

// The session is kept in sessionStorage, so each browser tab signs in on its own (same as before).
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
  {
    auth: {
      storage: window.sessionStorage,
      storageKey: 'cg_supabase_auth',
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
  },
)