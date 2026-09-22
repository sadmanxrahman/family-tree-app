import { useRouter } from 'expo-router';

import { Button } from '@/components/Button';
import { t } from '@/lib/i18n';

/** Entry point to the developer tools screen. Renders nothing in production builds. */
export function DevToolsLink() {
  const router = useRouter();
  if (!__DEV__) return null;

  return (
    <Button
      label={t('dev.open')}
      variant="plain"
      icon="wrench-outline"
      onPress={() => router.push('/dev-tools')}
    />
  );
}
