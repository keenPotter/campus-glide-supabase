<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useNotificationStore } from '@/stores/notifications'
import { fullName, initials, ROLE_LABELS } from '@/lib/format'
import { useToast } from '@/composables/useToast'

const auth = useAuthStore()
const notifications = useNotificationStore()
const route = useRoute()
const router = useRouter()
const toast = useToast()
const sidebarOpen = ref(false)

// `also` lists other pages that belong to the same menu item,
// so the item stays highlighted on them (for example, the request detail page).
const navigation = computed(() => {
  const items = [{ name: 'Dashboard', to: { name: 'dashboard' }, icon: 'home' }]

  if (auth.isFaculty) {
    items.push(
      {
        name: 'My Requests',
        to: { name: 'requests.index' },
        icon: 'list',
        also: ['requests.show', 'requests.edit'],
      },
      { name: 'New Request', to: { name: 'requests.create' }, icon: 'plus' },
      { name: 'My Allocations', to: { name: 'allocations' }, icon: 'car' },
      {
        name: 'My Trip Schedule',
        to: { name: 'facultyTripSchedule' },
        icon: 'calendar',
      },
    )
  }
  if (auth.isStaff) {
    items.push(
      { name: 'Allocations', to: { name: 'allocations' }, icon: 'car' },
      { name: 'Trip Schedule', to: { name: 'tripSchedule' }, icon: 'calendar' },
    )
  }

  if (auth.isAdministrator) {
    items.push(
      {
        name: 'Vehicle Requests',
        to: { name: 'requests.index' },
        icon: 'list',
        also: ['requests.show'],
        badge: notifications.pendingRequests,
      },
      {
        name: 'Allocations',
        to: { name: 'allocations' },
        icon: 'car',
        badge: notifications.allocationAttention,
      },
      { name: 'Trip Schedule', to: { name: 'tripSchedule' }, icon: 'calendar' },
      {
        name: 'Maintenance',
        to: { name: 'maintenance' },
        icon: 'wrench',
        badge: notifications.openMaintenance,
      },
      {
        name: 'Preventive Maintenance',
        to: { name: 'preventiveMaintenance' },
        icon: 'wrench',
      },
      { name: 'Users', to: { name: 'users.index' }, icon: 'users' },
      { name: 'Create User', to: { name: 'users.create' }, icon: 'user-plus' },
    )
  }

  return items
})

const icons = {
  home: 'M3 10.5 12 3l9 7.5M5.5 9v11h13V9M9.5 20v-6h5v6',
  grid: 'M3 3h7v9H3zM14 3h7v5h-7zM14 12h7v9h-7zM3 16h7v5H3z',
  list: 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01',
  plus: 'M12 5v14M5 12h14',
  car: 'M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2M9 17h6M7 15a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM17 15a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
  calendar: 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
  wrench: 'M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94z',
  'user-plus': 'M15 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM19 8v6M16 11h6',
  users: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
}

function isActive(item) {
  return [item.to.name, ...(item.also ?? [])].includes(route.name)
}

function badgeLabel(count) {
  return count > 99 ? '99+' : String(count)
}

// Only administrators see the numbers. Refresh when the page loads and on every page change.
function refreshBadges() {
  if (auth.isAdministrator) {
    notifications.refresh()
  }
}

onMounted(refreshBadges)
watch(() => route.fullPath, refreshBadges)

async function handleLogout() {
  await auth.logout()
  notifications.reset()
  toast.success('Signed out successfully.')
  router.push({ name: 'login' })
}

function closeSidebar() {
  sidebarOpen.value = false
}
</script>

<template>
  <div class="min-h-screen bg-surface">
    <!-- Mobile + Tablet Header (hamburger) -->
    <header class="sticky top-0 z-40 flex h-14 items-center justify-between gap-3 border-b border-line bg-white px-page lg:hidden">
      <button
        type="button"
        class="relative rounded-card p-2 text-ink-muted hover:bg-neutral-100"
        @click="sidebarOpen = !sidebarOpen"
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 6h16M4 12h16M4 18h16" />
        </svg>
        <!-- Dot: something needs attention inside the menu -->
        <span
          v-if="notifications.total > 0"
          class="absolute right-1 top-1 h-2.5 w-2.5 rounded-full bg-secondary ring-2 ring-white"
        />
      </button>

      <div class="flex h-8 w-8 items-center justify-center rounded-card bg-primary text-white text-small font-semibold">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 17V9l2-4h9l3 4h4v8" />
        </svg>
      </div>

      <button
        type="button"
        class="rounded-card p-2 text-ink-muted hover:bg-neutral-100 hover:text-red-600 ml-auto"
        title="Sign out"
        @click="handleLogout"
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
        </svg>
      </button>
    </header>

    <!-- Mobile + Tablet Sidebar Overlay -->
    <Transition
      enter-active-class="transition duration-200"
      enter-from-class="opacity-0"
      leave-active-class="transition duration-200"
      leave-to-class="opacity-0"
    >
      <div
        v-if="sidebarOpen"
        class="fixed inset-0 z-30 bg-ink/40 lg:hidden"
        @click="closeSidebar"
      />
    </Transition>

    <!-- Sidebar (always visible on laptop and up) -->
    <aside
      class="fixed inset-y-0 left-0 z-40 w-64 border-r border-line bg-white transition-transform"
      :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'"
    >
      <div class="flex h-16 items-center gap-2 border-b border-line px-card">
        <div class="flex h-8 w-8 items-center justify-center rounded-card bg-primary text-white">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 17V9l2-4h9l3 4h4v8" />
          </svg>
        </div>
        <div>
          <p class="text-small font-semibold leading-tight">CampusGlide</p>
          <p class="text-xs text-ink-muted">NVSU Motorpool</p>
        </div>
      </div>

      <nav class="flex flex-col gap-1 p-2">
        <RouterLink
          v-for="item in navigation"
          :key="item.name"
          :to="item.to"
          class="flex h-control items-center gap-3 rounded-card px-3 text-small transition md:text-body"
          :class="
            isActive(item)
              ? 'bg-primary-50 font-medium text-primary-700'
              : 'text-ink-muted hover:bg-neutral-100 hover:text-ink'
          "
          @click="closeSidebar"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path :d="icons[item.icon]" />
          </svg>
          {{ item.name }}

          <span
            v-if="item.badge > 0"
            class="ml-auto inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-secondary px-1.5 text-xs font-semibold text-white"
            :aria-label="`${item.badge} need attention`"
          >
            {{ badgeLabel(item.badge) }}
          </span>
        </RouterLink>
      </nav>
    </aside>

    <!-- Main Content -->
    <div class="lg:pl-64">
      <!-- Desktop Header -->
      <header class="sticky top-0 z-20 hidden lg:flex h-16 items-center justify-between gap-4 border-b border-line bg-white px-page">
        <div class="ml-auto flex items-center gap-3">
          <div class="text-right">
            <p class="text-small font-medium leading-tight">{{ auth.user?.first_name }}</p>
            <p class="text-small text-ink-muted">{{ ROLE_LABELS[auth.role] ?? auth.role }}</p>
          </div>
          <div class="flex h-10 w-10 items-center justify-center rounded-full bg-primary-50 text-small font-semibold text-primary-700">
            {{ initials(fullName(auth.user)) }}
          </div>
          <button
            type="button"
            class="rounded-card p-2 text-ink-muted hover:bg-neutral-100 hover:text-red-600"
            title="Sign out"
            @click="handleLogout"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
            </svg>
          </button>
        </div>
      </header>

      <main class="p-page pb-20 lg:pb-page">
        <slot />
      </main>
    </div>
  </div>
</template>