import { supabase } from '@/lib/supabase';

import { authRedirectUrl } from '../session';

/**
 * Sends one email containing both a magic link and a one-time code (the code appears only
 * once the Supabase email templates include {{ .Token }}). New and returning people use
 * the same path: Supabase creates the account on first verification.
 */
export async function sendMagicLink(email: string): Promise<void> {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: authRedirectUrl, shouldCreateUser: true },
  });
  if (error) throw error;
}

/** Backup for when the link can't open the app: the code from the same email. */
export async function verifyEmailCode(email: string, code: string): Promise<void> {
  const { error } = await supabase.auth.verifyOtp({ email, token: code, type: 'email' });
  if (error) throw error;
}
