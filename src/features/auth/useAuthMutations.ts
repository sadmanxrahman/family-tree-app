import { useMutation } from '@tanstack/react-query';

import { reportError } from '@/lib/errors';

import { AuthFailure, classifyAuthError, isExpectedFailure } from './authErrors';
import { sendMagicLink, verifyEmailCode } from './email/emailAuth';
import { exchangeAuthCode, signOut } from './session';

/**
 * Every auth mutation rejects with an AuthFailure rather than a raw error, so screens
 * only decide how to phrase a failure. Unexpected failures are reported here, once.
 */
function withReason<TArgs>(action: string, fn: (args: TArgs) => Promise<void>) {
  return async (args: TArgs): Promise<void> => {
    try {
      await fn(args);
    } catch (error) {
      const reason = classifyAuthError(error);
      if (!isExpectedFailure(reason)) reportError(error, { area: 'auth', action });
      throw new AuthFailure(reason);
    }
  };
}

export function useSendMagicLink() {
  return useMutation<void, AuthFailure, { email: string }>({
    mutationFn: withReason('sendMagicLink', ({ email }) => sendMagicLink(email)),
  });
}

export function useVerifyEmailCode() {
  return useMutation<void, AuthFailure, { email: string; code: string }>({
    mutationFn: withReason('verifyEmailCode', ({ email, code }) => verifyEmailCode(email, code)),
  });
}

export function useExchangeAuthCode() {
  return useMutation<void, AuthFailure, { code: string; flowId?: string }>({
    mutationFn: withReason('exchangeAuthCode', ({ code, flowId }) =>
      exchangeAuthCode(code, flowId),
    ),
  });
}

export function useSignOut() {
  return useMutation<void, AuthFailure, void>({
    mutationFn: withReason('signOut', () => signOut()),
  });
}
