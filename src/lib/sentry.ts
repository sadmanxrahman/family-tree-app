import * as Sentry from '@sentry/react-native';

const dsn = process.env.EXPO_PUBLIC_SENTRY_DSN;

/** Starts crash and error reporting. Does nothing until a DSN is set in .env. */
export function initSentry(): void {
  if (!dsn) return;
  Sentry.init({
    dsn,
    // Family data is private: never attach IP addresses, cookies or request bodies.
    sendDefaultPii: false,
    // Errors from your own dev machine would drown out real ones.
    enabled: !__DEV__,
    tracesSampleRate: 0.2,
  });
}

export { Sentry };
