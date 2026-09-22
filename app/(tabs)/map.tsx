import { PlaceholderScreen } from '@/components/PlaceholderScreen';
import { t } from '@/lib/i18n';

export default function MapTab() {
  return (
    <PlaceholderScreen
      icon="map-marker-radius-outline"
      title={t('map.placeholderTitle')}
      body={t('map.placeholderBody')}
    />
  );
}
