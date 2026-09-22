import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { Button } from '@/components/Button';
import { Screen } from '@/components/Screen';
import { useAuthStore } from '@/features/auth/authStore';
import { useTheme } from '@/hooks/useTheme';
import { posthog } from '@/lib/analytics';
import { useFlags, type FlagKey } from '@/lib/flags';
import { t } from '@/lib/i18n';
import { isSentryEnabled } from '@/lib/sentry';

// Deliberately broken component for testing the render ErrorBoundary.
function RenderCrash(): never {
  throw new Error('Dev tools: deliberate render crash');
}

/**
 * Development-only checks for monitoring and flags. Only reachable when __DEV__ is true
 * (see app/dev-tools.tsx), so none of this ships to real users.
 */
export function DevToolsScreen() {
  const { colors, radii, spacing, typography } = useTheme();
  const userId = useAuthStore((state) => state.session?.user.id);
  const { flags, status } = useFlags();
  const [crashRender, setCrashRender] = useState(false);

  const flagStatusLabel = {
    loading: t('dev.flagsLoading'),
    loaded: t('dev.flagsLoaded'),
    defaults: t('dev.flagsDefaults'),
  }[status];

  const section = [
    styles.section,
    {
      backgroundColor: colors.surface,
      borderColor: colors.border,
      borderRadius: radii.lg,
      padding: spacing.lg,
      gap: spacing.md,
    },
  ];
  const heading = [typography.heading, { color: colors.text }];
  const body = [typography.body, { color: colors.textMuted }];

  return (
    <Screen>
      {crashRender && <RenderCrash />}

      <Text style={body}>{t('dev.intro')}</Text>
      <Text selectable style={body}>
        {t('dev.accountId', { id: userId ?? '—' })}
      </Text>

      <View style={section}>
        <Text accessibilityRole="header" style={heading}>
          {t('dev.sentryHeading')}
        </Text>
        <Text style={body}>{isSentryEnabled ? t('dev.sentryOn') : t('dev.sentryOff')}</Text>
        <Text style={body}>{t('dev.redScreenNote')}</Text>
        <Button
          label={t('dev.throwError')}
          variant="secondary"
          icon="alert-octagon-outline"
          onPress={() => {
            throw new Error('Dev tools: deliberate uncaught error');
          }}
        />
        <Button
          label={t('dev.rejectPromise')}
          variant="secondary"
          icon="timer-sand-complete"
          onPress={() => {
            void Promise.reject(new Error('Dev tools: deliberate unhandled promise rejection'));
          }}
        />
        <Button
          label={t('dev.crashRender')}
          variant="secondary"
          icon="bomb"
          onPress={() => setCrashRender(true)}
        />
      </View>

      <View style={section}>
        <Text accessibilityRole="header" style={heading}>
          {t('dev.posthogHeading')}
        </Text>
        <Text style={body}>{posthog ? t('dev.posthogOn') : t('dev.posthogOff')}</Text>
      </View>

      <View style={section}>
        <Text accessibilityRole="header" style={heading}>
          {t('dev.flagsHeading')}
        </Text>
        <Text style={body}>{flagStatusLabel}</Text>
        {(Object.keys(flags) as FlagKey[]).map((key) => (
          <View key={key} style={styles.flagRow} accessible>
            <Text style={[typography.body, styles.flagKey, { color: colors.text }]}>{key}</Text>
            <Text
              style={[
                typography.bodyStrong,
                { color: flags[key] ? colors.success : colors.textMuted },
              ]}
            >
              {flags[key] ? t('dev.on') : t('dev.off')}
            </Text>
          </View>
        ))}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  section: { borderWidth: 1 },
  flagRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    minHeight: 32,
    gap: 12,
  },
  flagKey: { flexShrink: 1 },
});
