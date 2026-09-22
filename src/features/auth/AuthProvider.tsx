import type { User } from '@supabase/supabase-js';
import { useEffect, type ReactNode } from 'react';

import { identifyAnalyticsUser, track } from '@/lib/analytics';
import { queryClient } from '@/lib/queryClient';
import { setSentryUser } from '@/lib/sentry';
import { supabase } from '@/lib/supabase';

import { useAuthStore } from './authStore';
import { confirmAdult } from './session';

// An account whose email was confirmed this recently is completing its first sign-in.
// Returning accounts were confirmed long ago. Generous, because the person may take a
// few minutes between requesting the email and tapping the link.
const NEW_ACCOUNT_WINDOW_MS = 15 * 60 * 1000;

function isFirstSignIn(user: User): boolean {
  if (!user.email_confirmed_at) return false;
  return Date.now() - Date.parse(user.email_confirmed_at) < NEW_ACCOUNT_WINDOW_MS;
}

/**
 * Keeps the auth store in sync with Supabase. Supabase emits INITIAL_SESSION once it has
 * read the saved session from secure storage, which is what ends the 'restoring' state.
 */
export function AuthProvider({ children }: { children: ReactNode }) {
  const setSession = useAuthStore((state) => state.setSession);

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event, session) => {
      setSession(session);

      // Errors and analytics carry the account id only — never email or name.
      const userId = session?.user.id ?? null;
      setSentryUser(userId);
      if (userId) identifyAnalyticsUser(userId);

      if (event === 'SIGNED_IN' && session) {
        // Supabase warns against awaiting its own calls inside this callback (it can
        // deadlock), so defer to the next tick. Every sign-in method passes the welcome
        // screen's 18+ checkbox first, so any fresh sign-in has confirmed.
        setTimeout(() => void confirmAdult(), 0);

        if (isFirstSignIn(session.user)) {
          track('signed_up', { method: session.user.app_metadata.provider ?? 'unknown' });
        }
      }
      if (event === 'SIGNED_OUT') {
        // Never show the next person on this phone the previous account's cached data,
        // and start a fresh anonymous analytics identity.
        queryClient.clear();
        identifyAnalyticsUser(null);
      }
    });
    return () => data.subscription.unsubscribe();
  }, [setSession]);

  return <>{children}</>;
}
