import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

/**
 * Covers the app while the saved session is read at launch, so a signed-in person never
 * glimpses the sign-in screen. Normally hidden behind the native splash screen; it only
 * becomes visible if restoring is slow (e.g. refreshing an expired token on a bad network).
 */
export function SessionRestoringOverlay() {
  const { colors, spacing, typography } = useTheme();

  return (
    <View
      style={[
        StyleSheet.absoluteFill,
        styles.container,
        { backgroundColor: colors.background, gap: spacing.md },
      ]}
    >
      <ActivityIndicator size="large" color={colors.primary} />
      <Text accessibilityLiveRegion="polite" style={[typography.body, { color: colors.textMuted }]}>
        {t('auth.restoring')}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});
