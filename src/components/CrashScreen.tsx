import { MaterialCommunityIcons } from '@expo/vector-icons';
import { StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

import { Button } from './Button';
import { Screen } from './Screen';

/** Shown in place of a screen that crashed while rendering. The error is already reported. */
export function CrashScreen({ onRetry }: { onRetry: () => void }) {
  const { colors, radii, spacing, typography } = useTheme();

  return (
    <Screen centered>
      <View style={[styles.header, { gap: spacing.md }]}>
        <View
          style={[styles.icon, { backgroundColor: colors.surfaceMuted, borderRadius: radii.pill }]}
        >
          <MaterialCommunityIcons name="leaf-off" size={44} color={colors.danger} />
        </View>
        <Text
          accessibilityRole="header"
          style={[typography.title, styles.centered, { color: colors.text }]}
        >
          {t('crash.title')}
        </Text>
        <Text style={[typography.body, styles.centered, { color: colors.textMuted }]}>
          {t('crash.body')}
        </Text>
      </View>
      <Button label={t('crash.retry')} icon="refresh" onPress={onRetry} />
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
