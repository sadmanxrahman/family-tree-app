/**
 * Runs on every incoming deep link before Expo Router matches it to a screen.
 *
 * Supabase reports some sign-in failures (e.g. an expired magic link) after a `#` in the
 * redirect URL, and Expo Router ignores that part. For the auth callback only, move the
 * fragment into the query string so AuthCallbackScreen can read it as normal params.
 */
export function redirectSystemPath({ path }: { path: string; initial: boolean }): string {
  const hashIndex = path.indexOf('#');
  if (hashIndex === -1) return path;

  const base = path.slice(0, hashIndex);
  const fragment = path.slice(hashIndex + 1);
  if (!/\/callback(\?|$)/.test(base) || fragment === '') return path;

  return `${base}${base.includes('?') ? '&' : '?'}${fragment}`;
}
