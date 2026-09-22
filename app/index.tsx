import { Redirect } from 'expo-router';

import { useAuthStore } from '@/features/auth/authStore';

// Signed-in people open on the family tree, the heart of the app; everyone else on welcome.
export default function Index() {
  const status = useAuthStore((state) => state.status);

  // SessionRestoringOverlay covers the screen until the saved session has been read.
  if (status === 'restoring') return null;
  return <Redirect href={status === 'signedIn' ? '/tree' : '/welcome'} />;
}
