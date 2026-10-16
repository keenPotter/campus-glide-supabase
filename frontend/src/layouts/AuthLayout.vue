<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import nvsuLogo from '@/assets/nvsu-logo.png'
import nvsuBuilding from '@/assets/nvsu-building.jpg'

const messages = [
  { title: 'Smarter Fleet Management', text: 'Manage campus transportation in one organized place.' },
  { title: 'Organized Trip Scheduling', text: 'Keep approved trips, schedules, drivers, and vehicles coordinated.' },
  { title: 'Reliable Campus Transportation', text: 'Help administrators and faculty coordinate transportation needs.' },
]
const activeMessage = ref(0)
let intervalId
onMounted(() => { intervalId = window.setInterval(() => { activeMessage.value = (activeMessage.value + 1) % messages.length }, 4500) })
onUnmounted(() => window.clearInterval(intervalId))
</script>

<template>
  <main class="grid min-h-screen bg-white lg:grid-cols-2">
    <section class="flex min-h-screen flex-col justify-center px-6 py-10 sm:px-10 lg:px-14 xl:px-20">
      <div class="mx-auto w-full max-w-xl">
        <slot />
      </div>
      <footer class="mt-12 text-center text-xs text-ink-muted">NVSU · Motorpool &amp; General Services Unit</footer>
    </section>

    <aside class="relative hidden min-h-screen overflow-hidden bg-primary-900 lg:block">
      <img :src="nvsuBuilding" alt="Nueva Vizcaya State University campus building" class="absolute inset-0 h-full w-full object-cover" />
      <div class="absolute inset-0 bg-gradient-to-br from-green-950/85 via-primary-800/75 to-emerald-700/70" />
      <div class="absolute -right-24 -top-24 h-80 w-80 rounded-full border border-white/20" />
      <div class="absolute -bottom-28 -left-20 h-96 w-96 rounded-full border border-white/15" />

      <div class="relative z-10 flex min-h-screen flex-col justify-between p-10 text-white xl:p-14">
        <div class="flex items-center gap-4">
          <img :src="nvsuLogo" alt="NVSU university seal" class="h-16 w-16 rounded-full bg-white p-1 object-contain shadow-lg" />
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.16em] text-white/80">Nueva Vizcaya State University</p>
            <p class="mt-1 text-xl font-bold">CampusGlide</p>
            <p class="text-sm text-white/80">Fleet Management System</p>
          </div>
        </div>

        <div class="max-w-xl pb-8" aria-live="polite" aria-atomic="true">
          <Transition name="feature" mode="out-in">
            <div :key="activeMessage" class="min-h-40">
              <div class="mb-5 h-1 w-14 rounded-full bg-amber-300" />
              <h2 class="max-w-lg text-4xl font-bold leading-tight text-white xl:text-5xl">{{ messages[activeMessage].title }}</h2>
              <p class="mt-5 max-w-md text-base leading-7 text-white/90">{{ messages[activeMessage].text }}</p>
            </div>
          </Transition>
          <div class="mt-8 flex items-center gap-2" aria-label="Feature slide controls">
            <button v-for="(message, index) in messages" :key="message.title" type="button" class="h-2.5 rounded-full transition-all" :class="activeMessage === index ? 'w-8 bg-white' : 'w-2.5 bg-white/50 hover:bg-white/80'" :aria-label="`Show feature ${index + 1}: ${message.title}`" :aria-pressed="activeMessage === index" @click="activeMessage = index" />
          </div>
        </div>
        <p class="text-xs text-white/70">NVSU-FR-PPS-13-02 · Motorpool &amp; General Services Unit</p>
      </div>
    </aside>
  </main>
</template>

<style scoped>
.feature-enter-active, .feature-leave-active { transition: opacity 220ms ease, transform 220ms ease; }
.feature-enter-from { opacity: 0; transform: translateY(8px); }
.feature-leave-to { opacity: 0; transform: translateY(-8px); }
@media (prefers-reduced-motion: reduce) { .feature-enter-active, .feature-leave-active { transition: none; } }
</style>
