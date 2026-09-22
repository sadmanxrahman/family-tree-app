import { useColorScheme } from 'react-native';

import { darkTheme, lightTheme, type Theme } from '@/lib/theme';

/** Returns the theme matching the phone's light/dark setting, and re-renders when it changes. */
export function useTheme(): Theme {
  return useColorScheme() === 'dark' ? darkTheme : lightTheme;
}
