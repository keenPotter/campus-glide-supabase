import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import './assets/main.css'

// Remove legacy persistent login from older builds. New login tokens are tab-session scoped.
localStorage.removeItem('cg_token')

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.mount('#app')