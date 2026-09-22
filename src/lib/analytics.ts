import PostHog from 'posthog-react-native';

const apiKey = process.env.EXPO_PUBLIC_POSTHOG_KEY;
const host = process.env.EXPO_PUBLIC_POSTHOG_HOST;

/**
 * Product analytics client, or null when no key is configured (e.g. local development).
 * Only ever send event names and non-identifying properties — never names of persons,
 * memory text or anything else a family has entrusted to us.
 */
export const posthog: PostHog | null = apiKey
  ? new PostHog(apiKey, { host, disabled: __DEV__ })
  : null;
