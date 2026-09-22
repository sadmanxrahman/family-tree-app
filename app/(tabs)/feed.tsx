import { PlaceholderScreen } from '@/components/PlaceholderScreen';
import { t } from '@/lib/i18n';

export default function FeedTab() {
  return (
    <PlaceholderScreen
      icon="image-multiple-outline"
      title={t('feed.placeholderTitle')}
      body={t('feed.placeholderBody')}
    />
  );
}
