import axios from 'axios'

export const TOKEN_KEY = 'cg_token'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000/api',
  headers: {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY)
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem(TOKEN_KEY)
      if (!window.location.pathname.startsWith('/login')) {
        window.location.assign('/login')
      }
    }
    return Promise.reject(error)
  },
)

/**
 * Laravel wraps top-level JsonResource responses in `data`, but nested
 * resources (e.g. login's `user` key) and plain json() payloads are not.
 */
export function unwrap(response) {
  const payload = response?.data
  if (payload && typeof payload === 'object' && 'data' in payload && !Array.isArray(payload)) {
    return payload.data
  }
  return payload
}

/** Turns a 422 response into a { field: 'first message' } map. */
export function validationErrors(error) {
  const errors = error?.response?.data?.errors
  if (!errors) return {}

  return Object.fromEntries(
    Object.entries(errors).map(([field, messages]) => [field, messages[0]]),
  )
}

export function errorMessage(error, fallback = 'Something went wrong. Please try again.') {
  return error?.response?.data?.message ?? fallback
}

export default api