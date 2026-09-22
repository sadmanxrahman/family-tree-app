import { Stack } from 'expo-router';

import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

export default function AuthLayout() {
  const { colors } = useTheme();

  return (
    <Stack
      screenOptions={{
        headerStyle: { backgroundColor: colors.background },
        headerTintColor: colors.primary,
        headerTitle: '',
        headerShadowVisible: false,
        headerBackTitle: t('common.back'),
        contentStyle: { backgroundColor: colors.background },
      }}
    >
      <Stack.Screen name="welcome" options={{ headerShown: false }} />
      <Stack.Screen name="sign-in" />
      <Stack.Screen name="check-email" />
      {/* No back button: there is nothing meaningful to go back to mid-sign-in. */}
      <Stack.Screen name="callback" options={{ headerShown: false, gestureEnabled: false }} />
      <Stack.Screen name="auth-error" options={{ headerShown: false }} />
    </Stack>
  );
}
