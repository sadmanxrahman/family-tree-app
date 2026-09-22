import * as Linking from 'expo-linking';

import { reportError } from '@/lib/errors';
import { supabase } from '@/lib/supabase';

/**
 * Provider-agnostic session operations. Every sign-in method ends up here: redirect-based
 * methods (magic link now, Google later) finish through exchangeAuthCode; native methods
 * (Apple later) produce a session directly. Either way, onAuthStateChange in AuthProvider
 * picks up the new session, so no screen ever navigates after sign-in by hand.
 */

/**
 * Where Supabase sends people back after a link or browser sign-in.
 * Expo Go: exp://<your Mac's LAN IP>:8081/--/callback. Standalone app: roots://callback.
 */
export const authRedirectUrl = Linking.createURL('callback');

// On Android a redirect can reach the app twice (browser result + deep link), and a
// PKCE code is single-use, so concurrent exchanges of the same code share one request.
const inFlightExchanges = new Map<string, Promise<void>>();

/**
 * @param flowId The `sb_flow_id` supabase-js appended to the redirect URL. Each sign-in
 * request stores its own verifier under its flow id; without it, supabase-js falls back
 * to the verifier of the MOST RECENT request, so tapping an older email's link would send
 * the wrong verifier and burn that link's single-use code.
 */
export function exchangeAuthCode(code: string, flowId?: string): Promise<void> {
  const existing = inFlightExchanges.get(code);
  if (existing) return existing;

  const exchange = supabase.auth
    .exchangeCodeForSession(code, flowId ? { flowId } : undefined)
    .then(({ error }) => {
      if (error) throw error;
    })
    .finally(() => {
      inFlightExchanges.delete(code);
    });
  inFlightExchanges.set(code, exchange);
  return exchange;
}

/** Records the 18+ confirmation the person gave on the welcome screen. Safe to call repeatedly. */
export async function confirmAdult(): Promise<void> {
  const { error } = await supabase.rpc('confirm_adult');
  // Not shown to the person: they are signed in and nothing they can do would fix it.
  // Reported so an account missing its confirmation can be followed up.
  if (error) reportError(error, { area: 'auth', action: 'confirmAdult' });
}

export async function signOut(): Promise<void> {
  // 'local' signs out this phone only; 'global' would also sign out their other devices.
  const { error } = await supabase.auth.signOut({ scope: 'local' });
  if (error) throw error;
}
