import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/Button';
import { Checkbox } from '@/components/Checkbox';
import { InlineError } from '@/components/InlineError';
import { Screen } from '@/components/Screen';
import { useTheme } from '@/hooks/useTheme';
import { reportError } from '@/lib/errors';
import { t } from '@/lib/i18n';

import {
  authErrorMessage,
  classifyAuthError,
  isExpectedFailure,
  type AuthFailureReason,
} from './authErrors';
import { signInMethods, type SignInMethod, type SignInMethodId } from './signInMethods';

export function WelcomeScreen() {
  const router = useRouter();
  const { colors, radii, spacing, typography } = useTheme();
  const [isAdult, setIsAdult] = useState(false);
  const [showAgeError, setShowAgeError] = useState(false);
  const [busyMethod, setBusyMethod] = useState<SignInMethodId | null>(null);
  const [failure, setFailure] = useState<AuthFailureReason | null>(null);

  const methods = signInMethods.filter((method) => method.isAvailable());

  async function start(method: SignInMethod) {
    // No under-18 accounts in v1.0: every method is gated on the same confirmation.
    if (!isAdult) {
      setShowAgeError(true);
      return;
    }
    setFailure(null);

    if (method.kind === 'screen') {
      router.push(method.href);
      return;
    }

    setBusyMethod(method.id);
    try {
      // On success AuthProvider sees the new session and the auth gate moves to the tabs.
      await method.run();
    } catch (error) {
      const reason = classifyAuthError(error);
      if (!isExpectedFailure(reason)) {
        reportError(error, { area: 'auth', action: `signIn:${method.id}` });
      }
      setFailure(reason);
    } finally {
      setBusyMethod(null);
    }
  }

  return (
    <Screen>
      <View style={[styles.hero, { gap: spacing.md }]}>
        <View
          style={[styles.logo, { backgroundColor: colors.surfaceMuted, borderRadius: radii.pill }]}
        >
          <MaterialCommunityIcons name="family-tree" size={56} color={colors.primary} />
        </View>
        <Text accessibilityRole="header" style={[typography.display, { color: colors.text }]}>
          {t('app.name')}
        </Text>
        <Text style={[typography.body, styles.centered, { color: colors.textMuted }]}>
          {t('app.tagline')}
        </Text>
      </View>

      <View style={{ gap: spacing.md }}>
        <Checkbox
          label={t('auth.welcome.ageConfirm')}
          checked={isAdult}
          onChange={(checked) => {
            setIsAdult(checked);
            if (checked) setShowAgeError(false);
          }}
        />
        {showAgeError && <InlineError message={t('auth.welcome.ageRequired')} />}
        {failure && <InlineError message={authErrorMessage(failure)} />}

        {methods.map((method) => (
          <Button
            key={method.id}
            label={t(method.labelKey)}
            icon={method.icon}
            loading={busyMethod === method.id}
            disabled={busyMethod !== null && busyMethod !== method.id}
            onPress={() => void start(method)}
          />
        ))}

        <Text style={[typography.caption, styles.centered, { color: colors.textMuted }]}>
          {t('auth.welcome.privacyNote')}
        </Text>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  hero: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logo: {
    width: 112,
    height: 112,
    alignItems: 'center',
    justifyContent: 'center',
  },
  centered: {
    textAlign: 'center',
  },
});
