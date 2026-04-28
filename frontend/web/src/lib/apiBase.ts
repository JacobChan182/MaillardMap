/** Public API base URL (Railway). No trailing slash. */
export function apiBase(): string {
  const explicit = (import.meta.env.VITE_API_BASE_URL ?? '').trim();
  if (explicit) return explicit.replace(/\/$/, '');
  // Production fallback so account actions (verify/reset) still work
  // when Firebase env injection is missing.
  return 'https://bigback-production.up.railway.app';
}
