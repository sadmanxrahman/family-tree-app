import { isAuthError, isAuthRetryableFetchError } from '@supabase/supabase-js';

import { t } from '@/lib/i18n';

export type AuthFailureReason =
  'rateLimited' | 'expiredOrInvalid' | 'wrongDevice' | 'serverError' | 'network' | 'unknown';

/** Maps a Supabase error code (from an API error or a redirect URL) to something we can explain. */
export function reasonFromCode(code: string | undefined): AuthFailureReason {
  switch (code) {
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'rateLimited';
    // Supabase uses this one code for both an expired link and a mistyped code.
    case 'otp_expired':
      return 'expiredOrInvalid';
    // PKCE: the link was opened somewhere other than the app install that requested it.
    case 'flow_state_not_found':
    case 'flow_state_expired':
    case 'bad_code_verifier':
    case 'pkce_code_verifier_not_found':
      return 'wrongDevice';
    default:
      return 'unknown';
  }
}

export function classifyAuthError(error: unknown): AuthFailureReason {
  // supabase-js uses AuthRetryableFetchError for two different things: status 0 when the
  // request never got a response (really offline), and 5xx when Supabase answered with
  // a server error (e.g. its email provider failed). Only the first is "no internet".
  if (isAuthRetryableFetchError(error)) {
    return error.status === 0 ? 'network' : 'serverError';
  }
  if (isAuthError(error)) return reasonFromCode(error.code);
  if (error instanceof TypeError && /network/i.test(error.message)) return 'network';
  return 'unknown';
}

/** Carries the classified reason so screens only decide how to phrase a failure. */
export class AuthFailure extends Error {
  constructor(readonly reason: AuthFailureReason) {
    super(`Auth failed: ${reason}`);
    this.name = 'AuthFailure';
  }
}

/**
 * Expected failures are the person's situation (offline, typo, old link). Server errors
 * and unknown errors are ours to fix, so they go to Sentry.
 */
export function isExpectedFailure(reason: AuthFailureReason): boolean {
  return reason !== 'unknown' && reason !== 'serverError';
}

export function authErrorMessage(reason: AuthFailureReason): string {
  return t(`authErrors.${reason}` as const);
}
