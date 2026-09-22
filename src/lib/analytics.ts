import PostHog from 'posthog-react-native';

import { reportError } from './errors';

const apiKey = process.env.EXPO_PUBLIC_POSTHOG_KEY;
const host = process.env.EXPO_PUBLIC_POSTHOG_HOST;

/**
 * Product analytics client, or null when no key is configured.
 * Enabled in development too so Expo Go can verify the setup; every event carries
 * `environment`, so filter on it in PostHog to exclude your own testing.
 */
export const posthog: PostHog | null = apiKey ? new PostHog(apiKey, { host }) : null;

if (posthog) {
  void posthog.register({ environment: __DEV__ ? 'development' : 'production' });
}

/**
 * Every event the app may send. Adding an event means adding it here first, so the
 * full list of what we collect is always in one reviewable place.
 */
export type AnalyticsEvent =
  | 'signed_up'
  | 'tree_created'
  | 'person_added'
  | 'memory_added'
  | 'invite_sent'
  | 'invite_accepted';

/**
 * Only counts, flags and short enum-like strings. Never names of persons, memory text,
 * emails, places or anything else a family has entrusted to us.
 */
export type AnalyticsProperties = Record<string, string | number | boolean | null>;

export function track(event: AnalyticsEvent, properties?: AnalyticsProperties): void {
  if (!posthog) return;
  try {
    posthog.capture(event, properties);
  } catch (error) {
    // Analytics must never break a feature; report and carry on.
    reportError(error, { area: 'analytics', action: `track:${event}` });
  }
}

/** Records a screen view. Pass the route pattern, never a URL with query params. */
export function trackScreen(pathname: string): void {
  if (!posthog) return;
  posthog.screen(pathname).catch((error: unknown) => {
    reportError(error, { area: 'analytics', action: 'trackScreen' });
  });
}

/** Links later events to the account id (never email or name). null on sign-out. */
export function identifyAnalyticsUser(userId: string | null): void {
  if (!posthog) return;
  if (userId) {
    posthog.identify(userId);
  } else {
    // A new anonymous id, so the next person on this phone isn't merged with the last.
    posthog.reset();
  }
}
