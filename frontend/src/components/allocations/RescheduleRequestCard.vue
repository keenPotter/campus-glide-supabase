<script setup>
import { ref } from 'vue'
import { Check, X } from 'lucide-vue-next'
import { formatDate } from '@/lib/format'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'

defineProps({
  item: { type: Object, required: true },
  isAdmin: { type: Boolean, default: false },
})

defineEmits(['approve', 'disapprove'])

const detailsOpen = ref(false)
</script>

<template>
  <article class="rounded-card border border-line bg-white p-card transition-colors hover:bg-neutral-50">
    <button
      type="button"
      class="w-full rounded-card text-left hover:filter-none"
      :aria-label="`View date change request for ${item.trip?.destination ?? 'trip'}`"
      @click="detailsOpen = true"
    >
      <div class="flex flex-wrap items-start justify-between gap-2">
        <div class="min-w-0">
          <p class="truncate font-medium text-ink">{{ item.trip?.destination ?? '—' }}</p>
          <p class="mt-0.5 text-small text-ink-muted">
            <template v-if="isAdmin">Requested by {{ item.requested_by ?? '—' }} · </template>
            {{ formatDate(item.old_date) }} → <strong>{{ formatDate(item.new_date) }}</strong>
          </p>
        </div>
        <StatusBadge :status="item.status" />
      </div>

      <p class="mt-2 text-small text-ink-muted">Reason: {{ item.reason }}</p>
      <p v-if="item.admin_reason" class="mt-1 text-small text-ink-muted">
        Administrator's note: {{ item.admin_reason }}
      </p>
    </button>

    <div v-if="isAdmin && item.status === 'pending'" class="mt-3 flex items-center justify-end gap-2">
      <BaseButton size="sm" variant="outline" @click="$emit('disapprove', item)">
        <X :size="16" aria-hidden="true" /> Disapprove
      </BaseButton>
      <BaseButton size="sm" @click="$emit('approve', item)">
        <Check :size="16" aria-hidden="true" /> Approve
      </BaseButton>
    </div>
  </article>

  <BaseModal
    :open="detailsOpen"
    title="Date change request"
    :subtitle="item.trip?.destination ?? ''"
    @close="detailsOpen = false"
  >
    <dl class="divide-y divide-line">
      <div v-if="isAdmin" class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-small text-ink-muted">Requested by</dt>
        <dd class="text-body sm:col-span-2">{{ item.requested_by ?? '—' }}</dd>
      </div>
      <div class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-small text-ink-muted">Status</dt>
        <dd class="sm:col-span-2"><StatusBadge :status="item.status" /></dd>
      </div>
      <div class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-small text-ink-muted">Current date</dt>
        <dd class="text-body sm:col-span-2">{{ formatDate(item.old_date) }}</dd>
      </div>
      <div class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-small text-ink-muted">Requested date</dt>
        <dd class="text-body sm:col-span-2">{{ formatDate(item.new_date) }}</dd>
      </div>
      <div class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-small text-ink-muted">Reason</dt>
        <dd class="text-body sm:col-span-2">{{ item.reason || '—' }}</dd>
      </div>
      <div v-if="item.admin_reason" class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-3 sm:gap-4">
        <dt class="text-small text-ink-muted">Administrator's note</dt>
        <dd class="text-body sm:col-span-2">{{ item.admin_reason }}</dd>
      </div>
    </dl>
  </BaseModal>
</template>