import { PlaceholderScreen } from '@/components/PlaceholderScreen';
import { t } from '@/lib/i18n';

export default function ProfileTab() {
  return (
    <PlaceholderScreen
      icon="account-circle-outline"
      title={t('profile.placeholderTitle')}
      body={t('profile.placeholderBody')}
    />
  );
}
