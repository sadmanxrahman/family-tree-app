import type { MaterialCommunityIcons } from '@expo/vector-icons';
import type { Href } from 'expo-router';
import type { ComponentProps } from 'react';

import type { TranslationKey } from '@/lib/i18n';

/**
 * The sign-in methods offered on the welcome screen. The welcome screen renders whatever
 * is in this list, so adding a method never means editing the screens.
 *
 * Two shapes cover every provider Supabase supports:
 * - `screen`: the method needs more input first (email address), so it opens its own screen.
 * - `action`: the method runs in one step (native Apple sheet, Google in a browser) and
 *   resolves once Supabase has a session, or with 'cancelled' if the person backed out.
 *
 * Deferred to Phase 7 (needs an Apple Developer account and a development build):
 * Apple — an `action` calling expo-apple-authentication, then supabase.auth.signInWithIdToken.
 * Google — an `action` calling supabase.auth.signInWithOAuth with redirectTo = authRedirectUrl,
 * then exchangeAuthCode from session.ts on the returned code.
 */

export type SignInMethodId = 'email';

type IconName = ComponentProps<typeof MaterialCommunityIcons>['name'];

type SignInMethodBase = {
  id: SignInMethodId;
  labelKey: TranslationKey;
  icon: IconName;
  /** Platform or device support, e.g. Apple is iOS-only. */
  isAvailable: () => boolean;
};

export type SignInMethod =
  | (SignInMethodBase & { kind: 'screen'; href: Href })
  | (SignInMethodBase & { kind: 'action'; run: () => Promise<'signedIn' | 'cancelled'> });

export const signInMethods: readonly SignInMethod[] = [
  {
    id: 'email',
    kind: 'screen',
    href: '/sign-in',
    labelKey: 'auth.welcome.continueWithEmail',
    icon: 'email-outline',
    isAvailable: () => true,
  },
];
