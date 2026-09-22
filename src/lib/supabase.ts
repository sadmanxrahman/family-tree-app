// Supabase uses the web URL API, which React Native only partly implements.
import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  // Fail loudly at startup rather than with confusing network errors later.
  throw new Error(
    'Missing Supabase config. Copy .env.example to .env, fill in EXPO_PUBLIC_SUPABASE_URL ' +
      'and EXPO_PUBLIC_SUPABASE_ANON_KEY, then restart `npx expo start`.',
  );
}

// TODO: pass the generated Database type (src/types) once the first migration exists,
// so every query is type-checked against the real schema.
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    // Keeps people signed in between app launches.
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    // Only relevant on web, where the session arrives in the URL.
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
