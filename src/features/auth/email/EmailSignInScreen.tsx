import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'expo-router';
import { Controller, useForm } from 'react-hook-form';
import { Text } from 'react-native';
import { z } from 'zod';

import { Button } from '@/components/Button';
import { InlineError } from '@/components/InlineError';
import { Screen } from '@/components/Screen';
import { TextField } from '@/components/TextField';
import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

import { authErrorMessage } from '../authErrors';
import { useSendMagicLink } from '../useAuthMutations';

const schema = z.object({
  email: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.email({ error: t('auth.email.invalidEmail') })),
});

type FormInput = z.input<typeof schema>;
type FormOutput = z.output<typeof schema>;

export function EmailSignInScreen() {
  const router = useRouter();
  const { colors, typography } = useTheme();
  const sendMagicLink = useSendMagicLink();

  const { control, handleSubmit, formState } = useForm<FormInput, unknown, FormOutput>({
    resolver: zodResolver(schema),
    defaultValues: { email: '' },
  });

  const onSubmit = handleSubmit(({ email }) => {
    sendMagicLink.mutate(
      { email },
      { onSuccess: () => router.push({ pathname: '/check-email', params: { email } }) },
    );
  });

  return (
    <Screen>
      <Text accessibilityRole="header" style={[typography.title, { color: colors.text }]}>
        {t('auth.email.title')}
      </Text>
      <Text style={[typography.body, { color: colors.textMuted }]}>{t('auth.email.intro')}</Text>

      <Controller
        control={control}
        name="email"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label={t('auth.email.emailLabel')}
            placeholder={t('auth.email.emailPlaceholder')}
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            error={formState.errors.email?.message}
            keyboardType="email-address"
            textContentType="emailAddress"
            autoComplete="email"
            autoCapitalize="none"
            autoCorrect={false}
            autoFocus
            returnKeyType="send"
            onSubmitEditing={() => void onSubmit()}
          />
        )}
      />

      {sendMagicLink.error && (
        <InlineError message={authErrorMessage(sendMagicLink.error.reason)} />
      )}

      <Button
        label={t('auth.email.submit')}
        icon="send-outline"
        loading={sendMagicLink.isPending}
        onPress={() => void onSubmit()}
      />
    </Screen>
  );
}
