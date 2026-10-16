import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  { path: '/', redirect: { name: 'dashboard' } },
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { guestOnly: true },
  },
  {
    path: '/login/sign-in',
    name: 'login.form',
    component: () => import('@/views/LoginFormView.vue'),
    meta: { guestOnly: true },
  },
  {
    path: '/dashboard',
    name: 'dashboard',
    component: () => import('@/views/DashboardView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/requests',
    name: 'requests.index',
    component: () => import('@/views/requests/RequestListView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/requests/new',
    name: 'requests.create',
    component: () => import('@/views/requests/RequestFormView.vue'),
    meta: { requiresAuth: true, roles: ['faculty'] },
  },
  {
    path: '/requests/:id',
    name: 'requests.show',
    component: () => import('@/views/requests/RequestDetailView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/requests/:id/edit',
    name: 'requests.edit',
    component: () => import('@/views/requests/RequestFormView.vue'),
    meta: { requiresAuth: true, roles: ['faculty'] },
  },
  // Administrators manage allocations here. Faculty see their own allocations.
  // Changed: the page now lives in views/allocations (it was in modules/vehicle-driver-allocation).
  {
    path: '/allocations',
    name: 'allocations',
    component: () => import('@/views/allocations/AllocationsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/trip-schedule',
    name: 'tripSchedule',
    component: () => import('@/views/trip-schedule/TripScheduleView.vue'),
    meta: { requiresAuth: true, roles: ['administrator'] },
  },
  {
    path: '/my-trip-schedule',
    name: 'facultyTripSchedule',
    component: () => import('@/views/trip-schedule/FacultyTripScheduleView.vue'),
    meta: { requiresAuth: true, roles: ['faculty'] },
  },
  {
    path: '/maintenance',
    name: 'maintenance',
    component: () => import('@/views/maintenance/MaintenanceView.vue'),
    meta: { requiresAuth: true, roles: ['administrator'] },
  },
  {
    path: '/preventive-maintenance',
    name: 'preventiveMaintenance',
    component: () => import('@/views/maintenance/PreventiveMaintenanceView.vue'),
    meta: { requiresAuth: true, roles: ['administrator'] },
  },
  {
    path: '/users/new',
    name: 'users.create',
    component: () => import('@/views/users/CreateUserView.vue'),
    meta: { requiresAuth: true, roles: ['administrator'] },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'notFound',
    component: () => import('@/views/NotFoundView.vue'),
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  if (!auth.ready) {
    await auth.fetchUser()
  }

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  if (to.meta.guestOnly && auth.isAuthenticated) {
    return { name: 'dashboard' }
  }

  // Wrong role (for example, faculty typing /users/new): send back to the dashboard.
  if (to.meta.roles && !to.meta.roles.includes(auth.role)) {
    return { name: 'dashboard' }
  }

  return true
})

export default router