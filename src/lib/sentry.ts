import * as Sentry from '@sentry/react-native';

const dsn = process.env.EXPO_PUBLIC_SENTRY_DSN;

/** True when a DSN is configured, i.e. events are actually being sent. */
export const isSentryEnabled = Boolean(dsn);

/**
 * Starts crash and error reporting. Does nothing until EXPO_PUBLIC_SENTRY_DSN is set.
 *
 * Captured automatically once initialised:
 * - uncaught JS errors (global handler), including errors thrown in event handlers
 * - unhandled promise rejections
 * - render errors, via the ErrorBoundary exported from app/_layout.tsx
 */
export function initSentry(): void {
  if (!dsn) return;
  Sentry.init({
    dsn,
    // Enabled in development too, so Expo Go can verify the setup; filter by environment
    // in the Sentry UI to keep your own testing out of real-user numbers.
    environment: __DEV__ ? 'development' : 'production',
    // Family data is private: no IP addresses, cookies or request bodies.
    sendDefaultPii: false,
    tracesSampleRate: __DEV__ ? 1.0 : 0.2,
    integrations: [
      // These are Sentry's defaults; listed explicitly because catching both is a
      // requirement, not an accident of configuration.
      Sentry.reactNativeErrorHandlersIntegration({
        onerror: true,
        onunhandledrejection: true,
        patchGlobalPromise: true,
      }),
    ],
  });
}

/** Tags every subsequent event with the account id only — never email or name. */
export function setSentryUser(userId: string | null): void {
  Sentry.setUser(userId ? { id: userId } : null);
}

export { Sentry };
