<script setup>
import { computed, onMounted, ref } from 'vue'
import api, { errorMessage } from '@/lib/api'
import { useToast } from '@/composables/useToast'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import { formatDateTime, fullName, ROLE_LABELS } from '@/lib/format'

const toast = useToast()
const users = ref([])
const loading = ref(false)
const search = ref('')
const editing = ref(null)
const editForm = ref(null)
const confirmDeleteUser = ref(null)
const saving = ref(false)
const roleOptions = [
  { value: 'faculty', label: 'User' },
  { value: 'staff', label: 'Staff' },
  { value: 'administrator', label: 'Administrator' },
]
const filteredUsers = computed(() => users.value.filter((u) =>
  `${fullName(u)} ${u.email} ${ROLE_LABELS[u.role] ?? u.role}`.toLowerCase().includes(search.value.toLowerCase()),
))

async function loadUsers() {
  loading.value = true
  try {
    const response = await api.get('/users')
    users.value = response.data?.data ?? response.data ?? []
  } catch (error) {
    toast.error(errorMessage(error, 'Unable to load users.'))
  } finally { loading.value = false }
}
function startEdit(user) {
  editing.value = user.id
  editForm.value = { first_name: user.first_name, last_name: user.last_name, email: user.email, position: user.position ?? '', phone_number: user.phone_number ?? '', role: user.role, password: '' }
}
function cancelEdit() { editing.value = null; editForm.value = null }
async function saveEdit(user) {
  saving.value = true
  try {
    const payload = { ...editForm.value }
    if (!payload.password) delete payload.password
    const response = await api.put(`/users/${user.id}`, payload)
    const updated = response.data?.data ?? response.data
    users.value = users.value.map((item) => item.id === user.id ? updated : item)
    cancelEdit()
    toast.success('User account updated.')
  } catch (error) { toast.error(errorMessage(error, 'Unable to update user account.')) }
  finally { saving.value = false }
}
async function requestDelete() {
  if (!confirmDeleteUser.value) return
  saving.value = true
  try {
    await api.delete(`/users/${confirmDeleteUser.value.id}`)
    toast.success('Account disabled and scheduled for deletion in 30 days. It can be restored during that period.')
    confirmDeleteUser.value = null
    await loadUsers()
  } catch (error) { toast.error(errorMessage(error, 'Unable to schedule account deletion.')) }
  finally { saving.value = false }
}
async function cancelDeletion(user) {
  saving.value = true
  try {
    const response = await api.post(`/users/${user.id}/cancel-deletion`)
    const restored = response.data?.data ?? response.data
    users.value = users.value.map((item) => item.id === user.id ? restored : item)
    toast.success('Account deletion cancelled. The account is active again.')
  } catch (error) { toast.error(errorMessage(error, 'Unable to cancel deletion.')) }
  finally { saving.value = false }
}
onMounted(loadUsers)
</script>

<template>
  <div class="mx-auto flex max-w-6xl flex-col gap-page">
    <div class="flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
      <div>
        <h1 class="text-page-title">User accounts</h1>
        <p class="mt-1 text-small text-ink-muted">View and manage CampusGlide accounts. Administrator accounts cannot be scheduled for deletion.</p>
      </div>
      <RouterLink to="/users/new" class="inline-flex h-control items-center justify-center gap-2 rounded-card px-4 text-body font-medium transition bg-primary text-white hover:bg-primary-600 active:bg-primary-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400 focus-visible:ring-offset-2 md:px-5">Create user</RouterLink>
    </div>

    <BaseCard>
      <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="font-semibold">All accounts <span class="text-small font-normal text-ink-muted">({{ filteredUsers.length }})</span></div>
        <div class="flex gap-2">
          <input v-model="search" class="field-control sm:w-72" placeholder="Search name, email, or role" aria-label="Search users" />
          <BaseButton variant="outline" size="sm" :disabled="loading" @click="loadUsers">Refresh</BaseButton>
        </div>
      </div>
      <div v-if="loading" class="py-8 text-center text-ink-muted">Loading accounts…</div>
      <div v-else-if="!filteredUsers.length" class="py-8 text-center text-ink-muted">No user accounts found.</div>
      <div v-else class="space-y-3">
        <article v-for="user in filteredUsers" :key="user.id" class="rounded-card border border-line p-4 transition hover:border-primary-200 hover:shadow-sm">
          <template v-if="editing === user.id">
            <form class="grid gap-3 sm:grid-cols-2" @submit.prevent="saveEdit(user)">
              <BaseInput v-model="editForm.first_name" label="First name" required />
              <BaseInput v-model="editForm.last_name" label="Last name" required />
              <BaseInput v-model="editForm.email" label="Email" type="email" required />
              <BaseSelect v-model="editForm.role" label="Role" :options="roleOptions" :disabled="user.role === 'administrator'" required />
              <BaseInput v-model="editForm.position" label="Position / designation" />
              <BaseInput v-model="editForm.phone_number" label="Phone number" />
              <div class="sm:col-span-2"><BaseInput v-model="editForm.password" label="New password (optional)" type="password" hint="Leave blank to keep the current password." /></div>
              <div class="flex flex-wrap justify-end gap-2 sm:col-span-2">
                <BaseButton type="button" variant="outline" @click="cancelEdit">Cancel</BaseButton>
                <BaseButton type="submit" :loading="saving">Confirm changes</BaseButton>
              </div>
            </form>
          </template>
          <template v-else>
            <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <h2 class="text-base font-semibold">{{ fullName(user) }}</h2>
                  <span class="rounded-full bg-primary-50 px-2.5 py-1 text-xs font-semibold text-primary-700">{{ ROLE_LABELS[user.role] ?? user.role }}</span>
                  <span v-if="user.deletion_requested_at" class="rounded-full bg-red-50 px-2.5 py-1 text-xs font-semibold text-red-700">Pending deletion</span>
                  <span v-else-if="!user.is_active" class="rounded-full bg-neutral-100 px-2.5 py-1 text-xs font-semibold text-neutral-600">Inactive</span>
                </div>
                <p class="mt-1 break-all text-small text-ink-muted">{{ user.email }}</p>
                <p v-if="user.position || user.phone_number" class="mt-1 text-small text-ink-muted">{{ [user.position, user.phone_number].filter(Boolean).join(' · ') }}</p>
                <p v-if="user.deletion_requested_at" class="mt-2 text-small text-red-700">Requested {{ formatDateTime(user.deletion_requested_at) }}. Deletion processing after {{ formatDateTime(user.deletion_due_at) }}. Historical requests, allocations, and trips will be retained.</p>
              </div>
              <div class="flex shrink-0 flex-wrap gap-2">
                <BaseButton v-if="user.deletion_requested_at" variant="outline" size="sm" :loading="saving" @click="cancelDeletion(user)">Cancel deletion</BaseButton>
                <template v-else-if="user.role !== 'administrator'">
                  <BaseButton variant="outline" size="sm" @click="startEdit(user)">Edit</BaseButton>
                  <BaseButton variant="danger" size="sm" @click="confirmDeleteUser = user">Delete account</BaseButton>
                </template>
                <BaseButton v-else variant="outline" size="sm" @click="startEdit(user)">Edit</BaseButton>
              </div>
            </div>
          </template>
        </article>
      </div>
    </BaseCard>

    <BaseModal :open="!!confirmDeleteUser" title="Delete User Account?" @close="confirmDeleteUser = null">
      <template v-if="confirmDeleteUser">
        <div class="space-y-4 text-body">
          <p>You are about to schedule this account for deletion.</p>
          <div class="rounded-card border border-line bg-neutral-50 p-3">
            <p><strong>User:</strong> {{ fullName(confirmDeleteUser) }}</p>
            <p class="mt-1 break-all"><strong>Email:</strong> {{ confirmDeleteUser.email }}</p>
          </div>
          <div>
            <p class="font-semibold">What will happen?</p>
            <ul class="mt-2 list-disc space-y-2 pl-5 text-small text-ink-muted">
              <li>The account will be disabled immediately, and the user will no longer be able to log in.</li>
              <li>The account is scheduled for permanent deletion after 30 full days. You can cancel the deletion before the deadline.</li>
              <li>Historical Vehicle Requests, Trip Schedules, Allocation records, and Maintenance records will be preserved according to the school's retention policy. Personal account details will be anonymized as part of deletion processing.</li>
            </ul>
          </div>
          <p>Please confirm that you want to proceed. This action will immediately disable the user's account.</p>
        </div>
        <div class="mt-6 flex justify-end gap-2">
          <BaseButton variant="outline" :disabled="saving" @click="confirmDeleteUser = null">Cancel</BaseButton>
          <BaseButton variant="danger" :loading="saving" @click="requestDelete">Confirm deletion</BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>