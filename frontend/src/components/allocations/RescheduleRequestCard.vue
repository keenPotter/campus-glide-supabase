<script setup>
import { formatDate } from '@/lib/format'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'

defineProps({
  item: { type: Object, required: true },
  isAdmin: { type: Boolean, default: false },
})

defineEmits(['approve', 'disapprove'])
</script>

<template>
  <article class="rounded-card border border-line bg-white p-card">
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

    <div v-if="isAdmin && item.status === 'pending'" class="mt-3 flex justify-end gap-2">
      <BaseButton size="sm" variant="outline" @click="$emit('disapprove', item)">Disapprove</BaseButton>
      <BaseButton size="sm" @click="$emit('approve', item)">Approve</BaseButton>
    </div>
  </article>
</template>