import { Redirect } from 'expo-router';

import { DevToolsScreen } from '@/features/dev/DevToolsScreen';

export default function DevToolsRoute() {
  // Test buttons that crash the app must never be reachable in a real build.
  if (!__DEV__) return <Redirect href="/" />;
  return <DevToolsScreen />;
}
