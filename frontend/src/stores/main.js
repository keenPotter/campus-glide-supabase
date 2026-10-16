import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { supabase } from './lib/supabase'
import { useAuthStore } from './stores/auth'
import './assets/main.css'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// If the session ends by itself (expired, or signed out in another tab), go to the login page.
// A normal sign-out is handled by the sign-out button.
const auth = useAuthStore()
supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_OUT' && auth.user) {
    auth.user = null
    if (router.currentRoute.value.meta.requiresAuth) {
      router.push({ name: 'login' })
    }
  }
})

app.mount('#app')