import { QueryClientProvider } from '@tanstack/react-query';
import {
  DarkTheme,
  DefaultTheme,
  Stack,
  ThemeProvider,
  type ErrorBoundaryProps,
  type Theme as NavTheme,
} from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { PostHogProvider } from 'posthog-react-native';
import { useEffect, type ReactNode } from 'react';

import { AuthProvider } from '@/features/auth/AuthProvider';
import { useAuthStore } from '@/features/auth/authStore';
import { SessionRestoringOverlay } from '@/features/auth/SessionRestoringOverlay';
import { CrashScreen } from '@/components/CrashScreen';
import { useScreenTracking } from '@/hooks/useScreenTracking';
import { useTheme } from '@/hooks/useTheme';
import { posthog } from '@/lib/analytics';
import { reportError } from '@/lib/errors';
import { t } from '@/lib/i18n';
import { queryClient } from '@/lib/queryClient';
import { initSentry, Sentry } from '@/lib/sentry';

initSentry();

// Keep the native splash up while the saved session is read, so a signed-in person
// never sees the sign-in screen flash past.
void SplashScreen.preventAutoHideAsync();

// Upper bound on the splash. If restoring is slow (expired token, bad network),
// SessionRestoringOverlay takes over with a visible loading state instead.
const MAX_SPLASH_MS = 3000;

function AnalyticsProvider({ children }: { children: ReactNode }) {
  if (!posthog) return <>{children}</>;
  // Screen autocapture doesn't work with Expo Router, and touch capture could record
  // the text of what people tap — which in this app may be a relative's name.
  return (
    <PostHogProvider
      client={posthog}
      autocapture={{ captureScreens: false, captureTouches: false }}
    >
      {children}
    </PostHogProvider>
  );
}

/**
 * The auth gate. Each group only exists while its guard is true, so signed-out people
 * cannot reach the tabs and signed-in people cannot land on sign-in screens. When the
 * session changes, Expo Router moves to the first screen that is still allowed (index),
 * which redirects to the right place.
 */
function RootNavigator() {
  const status = useAuthStore((state) => state.status);
  const isSignedIn = status === 'signedIn';
  useScreenTracking();

  useEffect(() => {
    if (status !== 'restoring') SplashScreen.hide();
  }, [status]);

  useEffect(() => {
    const timer = setTimeout(() => SplashScreen.hide(), MAX_SPLASH_MS);
    return () => clearTimeout(timer);
  }, []);

  return (
    <>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Protected guard={isSignedIn}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen
            name="dev-tools"
            options={{
              headerShown: true,
              title: t('dev.title'),
              headerBackTitle: t('common.back'),
            }}
          />
        </Stack.Protected>
        <Stack.Protected guard={!isSignedIn}>
          <Stack.Screen name="(auth)" />
        </Stack.Protected>
      </Stack>
      {status === 'restoring' && <SessionRestoringOverlay />}
    </>
  );
}

function RootLayout() {
  const theme = useTheme();
  const base = theme.scheme === 'dark' ? DarkTheme : DefaultTheme;

  // Feed our tokens into the navigation library so headers and tab bars match the app.
  const navTheme: NavTheme = {
    ...base,
    colors: {
      ...base.colors,
      primary: theme.colors.primary,
      background: theme.colors.background,
      card: theme.colors.surface,
      text: theme.colors.text,
      border: theme.colors.border,
      notification: theme.colors.accent,
    },
  };

  return (
    <AnalyticsProvider>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <ThemeProvider value={navTheme}>
            <RootNavigator />
            <StatusBar style="auto" />
          </ThemeProvider>
        </AuthProvider>
      </QueryClientProvider>
    </AnalyticsProvider>
  );
}

/**
 * Catches errors thrown while rendering any screen. Without this, Expo Router's built-in
 * boundary would catch them first and they would never reach Sentry.
 */
export function ErrorBoundary({ error, retry }: ErrorBoundaryProps) {
  useEffect(() => {
    reportError(error, { area: 'app', action: 'render' });
  }, [error]);

  return <CrashScreen onRetry={() => void retry()} />;
}

export default Sentry.wrap(RootLayout);
