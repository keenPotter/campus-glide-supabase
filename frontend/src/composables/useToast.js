import { reactive } from 'vue'

const toasts = reactive([])
let counter = 0

export function useToast() {
  function push(message, type = 'success', timeout = 4000) {
    const id = ++counter
    toasts.push({ id, message, type })
    setTimeout(() => dismiss(id), timeout)
  }

  function dismiss(id) {
    const index = toasts.findIndex((toast) => toast.id === id)
    if (index !== -1) toasts.splice(index, 1)
  }

  return {
    toasts,
    dismiss,
    success: (message) => push(message, 'success'),
    error: (message) => push(message, 'error'),
    info: (message) => push(message, 'info'),
  }
}