import { View } from 'react-native';

import { Button } from '@/components/Button';
import { InlineError } from '@/components/InlineError';
import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

import { authErrorMessage } from './authErrors';
import { useSignOut } from './useAuthMutations';

export function SignOutButton() {
  const { spacing } = useTheme();
  const signOut = useSignOut();

  return (
    <View style={{ gap: spacing.md, alignSelf: 'stretch' }}>
      {signOut.error && <InlineError message={authErrorMessage(signOut.error.reason)} />}
      <Button
        label={t('auth.signOut')}
        variant="secondary"
        icon="logout"
        loading={signOut.isPending}
        onPress={() => signOut.mutate()}
      />
    </View>
  );
}
