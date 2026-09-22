import { usePathname } from 'expo-router';
import { useEffect } from 'react';

import { trackScreen } from '@/lib/analytics';

/**
 * Sends a PostHog screen view on every route change. PostHog's own screen autocapture
 * needs a NavigationContainer, which Expo Router doesn't expose, so this replaces it.
 *
 * Only the pathname is sent — never search params, which can hold an email address
 * (e.g. /check-email?email=…).
 */
export function useScreenTracking(): void {
  const pathname = usePathname();

  useEffect(() => {
    trackScreen(pathname);
  }, [pathname]);
}
