import { QueryClientProvider } from '@tanstack/react-query';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider, type Theme as NavTheme } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { PostHogProvider } from 'posthog-react-native';
import type { ReactNode } from 'react';

import { useTheme } from '@/hooks/useTheme';
import { posthog } from '@/lib/analytics';
import { queryClient } from '@/lib/queryClient';
import { initSentry, Sentry } from '@/lib/sentry';

initSentry();

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
        <ThemeProvider value={navTheme}>
          <Stack screenOptions={{ headerShown: false }} />
          <StatusBar style="auto" />
        </ThemeProvider>
      </QueryClientProvider>
    </AnalyticsProvider>
  );
}

export default Sentry.wrap(RootLayout);
