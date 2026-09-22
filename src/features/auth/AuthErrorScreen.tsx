import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/Button';
import { Screen } from '@/components/Screen';
import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

import { authErrorMessage, type AuthFailureReason } from './authErrors';

const knownReasons: readonly AuthFailureReason[] = [
  'rateLimited',
  'expiredOrInvalid',
  'wrongDevice',
  'serverError',
  'network',
  'unknown',
];

function toReason(value: string | undefined): AuthFailureReason {
  // The reason arrives in a URL, so treat it as untrusted input.
  return knownReasons.find((reason) => reason === value) ?? 'unknown';
}

export function AuthErrorScreen() {
  const { reason } = useLocalSearchParams<{ reason?: string }>();
  const router = useRouter();
  const { colors, radii, spacing, typography } = useTheme();

  return (
    <Screen centered>
      <View style={[styles.header, { gap: spacing.md }]}>
        <View
          style={[styles.icon, { backgroundColor: colors.surfaceMuted, borderRadius: radii.pill }]}
        >
          <MaterialCommunityIcons name="link-variant-off" size={44} color={colors.danger} />
        </View>
        <Text
          accessibilityRole="header"
          style={[typography.title, styles.centered, { color: colors.text }]}
        >
          {t('auth.error.title')}
        </Text>
        <Text style={[typography.body, styles.centered, { color: colors.textMuted }]}>
          {authErrorMessage(toReason(reason))}
        </Text>
      </View>
      <Button label={t('auth.error.tryAgain')} onPress={() => router.replace('/welcome')} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { alignItems: 'center' },
  icon: {
    width: 88,
    height: 88,
    alignItems: 'center',
    justifyContent: 'center',
  },
  centered: { textAlign: 'center' },
});
