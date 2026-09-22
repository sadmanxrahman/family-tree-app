import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useRef } from 'react';
import { ActivityIndicator, Text } from 'react-native';

import { Screen } from '@/components/Screen';
import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

import { reasonFromCode } from './authErrors';
import { useExchangeAuthCode } from './useAuthMutations';

type CallbackParams = {
  code?: string;
  error?: string;
  error_code?: string;
  /** Added to the redirect by supabase-js; identifies which request this link belongs to. */
  sb_flow_id?: string;
};

/**
 * Landing screen for redirect-based sign-in (the magic link now, Google later).
 * Supabase appends either ?code=… (success) or error details; app/+native-intent.tsx
 * makes sure error details that arrive after a # are visible here too.
 */
export function AuthCallbackScreen() {
  const params = useLocalSearchParams<CallbackParams>();
  const router = useRouter();
  const { colors, typography } = useTheme();
  const { mutate: exchangeCode } = useExchangeAuthCode();
  const handledCode = useRef<string | null>(null);

  useEffect(() => {
    if (params.error || params.error_code) {
      router.replace({
        pathname: '/auth-error',
        params: { reason: reasonFromCode(params.error_code) },
      });
      return;
    }
    if (!params.code) {
      router.replace('/welcome');
      return;
    }
    // A code is single-use; never exchange the same one twice from this screen.
    if (handledCode.current === params.code) return;
    handledCode.current = params.code;

    exchangeCode(
      { code: params.code, flowId: params.sb_flow_id },
      {
        // Success needs no navigation: the auth gate moves to the tabs on the new session.
        onError: (failure) =>
          router.replace({ pathname: '/auth-error', params: { reason: failure.reason } }),
      },
    );
  }, [params, router, exchangeCode]);

  return (
    <Screen centered>
      <ActivityIndicator size="large" color={colors.primary} />
      <Text
        accessibilityLiveRegion="polite"
        style={[typography.body, { color: colors.textMuted, textAlign: 'center' }]}
      >
        {t('auth.callback.signingIn')}
      </Text>
    </Screen>
  );
}
