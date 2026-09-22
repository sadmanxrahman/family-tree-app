import type { Session } from '@supabase/supabase-js';
import { create } from 'zustand';

/**
 * - restoring: reading the saved session from secure storage at launch. The app shows the
 *   splash/loading view, never the sign-in screen, so signed-in people see no flash.
 * - signedIn / signedOut: settled.
 */
export type AuthStatus = 'restoring' | 'signedIn' | 'signedOut';

type AuthState = {
  status: AuthStatus;
  session: Session | null;
  setSession: (session: Session | null) => void;
};

export const useAuthStore = create<AuthState>()((set) => ({
  status: 'restoring',
  session: null,
  setSession: (session) => set({ session, status: session ? 'signedIn' : 'signedOut' }),
}));
