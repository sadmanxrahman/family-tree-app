import { PlaceholderScreen } from '@/components/PlaceholderScreen';
import { SignOutButton } from '@/features/auth/SignOutButton';
import { DevToolsLink } from '@/features/dev/DevToolsLink';
import { t } from '@/lib/i18n';

export default function ProfileTab() {
  return (
    <PlaceholderScreen
      icon="account-circle-outline"
      title={t('profile.placeholderTitle')}
      body={t('profile.placeholderBody')}
    >
      <SignOutButton />
      <DevToolsLink />
    </PlaceholderScreen>
  );
}
