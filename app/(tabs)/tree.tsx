import { PlaceholderScreen } from '@/components/PlaceholderScreen';
import { t } from '@/lib/i18n';

export default function TreeTab() {
  return (
    <PlaceholderScreen
      icon="family-tree"
      title={t('tree.placeholderTitle')}
      body={t('tree.placeholderBody')}
    />
  );
}
