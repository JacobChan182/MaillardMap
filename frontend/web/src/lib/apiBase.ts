/** Public API base URL (Railway). No trailing slash. */
export function apiBase(): string {
  return (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/$/, '');
}
