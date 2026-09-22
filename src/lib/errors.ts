import { Sentry } from './sentry';

type ErrorContext = {
  /** Feature area, e.g. "auth". */
  area: string;
  /** What was being attempted, e.g. "signInWithApple". */
  action: string;
  /** Extra non-identifying detail. Never emails, names or memory content. */
  extra?: Record<string, string | number | boolean | null>;
};

/** Sends an unexpected error to Sentry with context. The caller still shows the user a message. */
export function reportError(error: unknown, context: ErrorContext): void {
  if (__DEV__) {
    console.error(`[${context.area}] ${context.action} failed`, error);
  }
  Sentry.captureException(error, {
    tags: { area: context.area, action: context.action },
    extra: context.extra,
  });
}
