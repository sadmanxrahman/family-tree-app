import { Platform, type TextStyle } from 'react-native';

/**
 * Design tokens. Every colour, size and spacing value in the app comes from here,
 * so the look can change in one place and dark mode is never an afterthought.
 *
 * The palette is deliberately warm — paper, terracotta, moss, honey — because this
 * is an app about family and memory, not a dashboard.
 */

type ColorTokens = {
  /** Screen background. */
  background: string;
  /** Cards, sheets, tab bar. */
  surface: string;
  /** Subtle fills: input backgrounds, pressed states, placeholders. */
  surfaceMuted: string;
  border: string;
  text: string;
  /** Secondary text. Still meets WCAG AA (4.5:1) against background. */
  textMuted: string;
  /** Main action colour. */
  primary: string;
  onPrimary: string;
  secondary: string;
  onSecondary: string;
  /** Highlights such as anniversaries and "new memory" markers. */
  accent: string;
  danger: string;
  success: string;
};

const lightColors: ColorTokens = {
  background: '#FBF6EF',
  surface: '#FFFDF9',
  surfaceMuted: '#F2E9DD',
  border: '#E3D6C5',
  text: '#2A211C',
  textMuted: '#6B5C50',
  primary: '#A4502C',
  onPrimary: '#FFFFFF',
  secondary: '#4F6B4A',
  onSecondary: '#FFFFFF',
  accent: '#B7832F',
  danger: '#B3261E',
  success: '#3F7A4A',
};

const darkColors: ColorTokens = {
  background: '#1C1714',
  surface: '#26201C',
  surfaceMuted: '#312924',
  border: '#44392F',
  text: '#F4ECE3',
  textMuted: '#B9A999',
  primary: '#E39A74',
  onPrimary: '#2A1508',
  secondary: '#9DBB95',
  onSecondary: '#16210F',
  accent: '#E2B866',
  danger: '#F2B8B5',
  success: '#8FC79A',
};

export const spacing = {
  xxs: 2,
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
  xxxl: 48,
} as const;

export const radii = {
  sm: 6,
  md: 12,
  lg: 20,
  pill: 999,
} as const;

/** CLAUDE.md rule 9: nothing tappable is smaller than 44×44. */
export const minTouchTarget = 44;

// A serif for headings gives the app a keepsake, storybook feel. These are system
// fonts, so there is nothing to download and they respect the user's font size setting.
const serif = Platform.select({ ios: 'Georgia', android: 'serif', default: 'serif' });

export const typography = {
  display: { fontFamily: serif, fontSize: 34, lineHeight: 40, fontWeight: '700' },
  title: { fontFamily: serif, fontSize: 26, lineHeight: 32, fontWeight: '700' },
  heading: { fontSize: 20, lineHeight: 26, fontWeight: '600' },
  body: { fontSize: 17, lineHeight: 24, fontWeight: '400' },
  bodyStrong: { fontSize: 17, lineHeight: 24, fontWeight: '600' },
  label: { fontSize: 15, lineHeight: 20, fontWeight: '500' },
  caption: { fontSize: 13, lineHeight: 18, fontWeight: '400' },
} as const satisfies Record<string, TextStyle>;

export type ColorScheme = 'light' | 'dark';

export type Theme = {
  scheme: ColorScheme;
  colors: ColorTokens;
  spacing: typeof spacing;
  radii: typeof radii;
  typography: typeof typography;
};

export const lightTheme: Theme = {
  scheme: 'light',
  colors: lightColors,
  spacing,
  radii,
  typography,
};
export const darkTheme: Theme = { scheme: 'dark', colors: darkColors, spacing, radii, typography };
