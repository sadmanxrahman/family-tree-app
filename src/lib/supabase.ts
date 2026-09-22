// Supabase uses the web URL API, which React Native only partly implements.
import 'react-native-url-polyfill/auto';
// Must load before createClient: gives PKCE secure randomness and SHA-256.
import './cryptoPolyfill';

import { createClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';

import { secureStorage } from './secureStorage';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  // Fail loudly at startup rather than with confusing network errors later.
  throw new Error(
    'Missing Supabase config. Copy .env.example to .env, fill in EXPO_PUBLIC_SUPABASE_URL ' +
      'and EXPO_PUBLIC_SUPABASE_ANON_KEY, then restart `npx expo start`.',
  );
}

// TODO: pass the generated Database type (src/types) once there are more tables,
// so every query is type-checked against the real schema.
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    // Keychain/Keystore rather than plain storage: the refresh token is a long-lived
    // key to someone's family history.
    storage: secureStorage,
    autoRefreshToken: true,
    persistSession: true,
    // PKCE: the magic link and Google redirect carry a one-time code rather than the
    // tokens themselves, so a leaked link or URL is useless on another device.
    flowType: 'pkce',
    // Deep links are handled explicitly by the /callback route.
    detectSessionInUrl: false,
  },
});

// Mobile apps are suspended in the background, so token refresh timers are unreliable.
// Supabase recommends refreshing only while the app is in the foreground.
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    void supabase.auth.startAutoRefresh();
  } else {
    void supabase.auth.stopAutoRefresh();
  }
});
