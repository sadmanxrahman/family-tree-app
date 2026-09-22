import { MaterialCommunityIcons } from '@expo/vector-icons';
import { zodResolver } from '@hookform/resolvers/zod';
import { Redirect, useLocalSearchParams, useRouter } from 'expo-router';
import { Controller, useForm } from 'react-hook-form';
import { StyleSheet, Text, View } from 'react-native';
import { z } from 'zod';

import { Button } from '@/components/Button';
import { InlineError } from '@/components/InlineError';
import { Screen } from '@/components/Screen';
import { TextField } from '@/components/TextField';
import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

import { authErrorMessage } from '../authErrors';
import { useSendMagicLink, useVerifyEmailCode } from '../useAuthMutations';

const schema = z.object({
  // Supabase codes are 6 digits by default; the length is configurable up to 10.
  code: z
    .string()
    .trim()
    .regex(/^\d{6,10}$/, { error: t('auth.checkEmail.invalidCode') }),
});

type FormValues = z.infer<typeof schema>;

export function CheckEmailScreen() {
  const { email } = useLocalSearchParams<{ email?: string }>();
  const router = useRouter();
  const { colors, radii, spacing, typography } = useTheme();
  const verifyCode = useVerifyEmailCode();
  const resend = useSendMagicLink();

  const { control, handleSubmit, formState } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { code: '' },
  });

  // Only reachable from the email screen; if the address is lost (e.g. a stale deep
  // link), start over rather than show a screen that can't do anything.
  if (!email) return <Redirect href="/sign-in" />;

  const onSubmitCode = handleSubmit(({ code }) => {
    // On success AuthProvider sees the session and the auth gate moves to the tabs.
    verifyCode.mutate({ email, code });
  });

  return (
    <Screen>
      <View style={[styles.header, { gap: spacing.md }]}>
        <View
          style={[styles.icon, { backgroundColor: colors.surfaceMuted, borderRadius: radii.pill }]}
        >
          <MaterialCommunityIcons name="email-fast-outline" size={44} color={colors.primary} />
        </View>
        <Text
          accessibilityRole="header"
          style={[typography.title, styles.centered, { color: colors.text }]}
        >
          {t('auth.checkEmail.title')}
        </Text>
        <Text style={[typography.body, styles.centered, { color: colors.textMuted }]}>
          {t('auth.checkEmail.body', { email })}
        </Text>
      </View>

      <Text style={[typography.body, { color: colors.text }]}>
        {t('auth.checkEmail.codeIntro')}
      </Text>
      <Controller
        control={control}
        name="code"
        render={({ field: { onChange, onBlur, value } }) => (
          <TextField
            label={t('auth.checkEmail.codeLabel')}
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            error={formState.errors.code?.message}
            keyboardType="number-pad"
            textContentType="oneTimeCode"
            autoComplete="one-time-code"
            maxLength={10}
            returnKeyType="done"
            onSubmitEditing={() => void onSubmitCode()}
          />
        )}
      />
      {verifyCode.error && <InlineError message={authErrorMessage(verifyCode.error.reason)} />}
      <Button
        label={t('auth.checkEmail.submitCode')}
        loading={verifyCode.isPending}
        onPress={() => void onSubmitCode()}
      />

      {resend.error && <InlineError message={authErrorMessage(resend.error.reason)} />}
      {resend.isSuccess && (
        <Text
          accessibilityLiveRegion="polite"
          style={[typography.body, styles.centered, { color: colors.success }]}
        >
          {t('auth.checkEmail.resent')}
        </Text>
      )}
      <Button
        label={t('auth.checkEmail.resend')}
        variant="secondary"
        icon="email-sync-outline"
        loading={resend.isPending}
        onPress={() => resend.mutate({ email })}
      />
      <Button
        label={t('auth.checkEmail.differentEmail')}
        variant="plain"
        onPress={() => router.back()}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: { alignItems: 'center' },
  icon: {
    width: 88,
    height: 88,
    alignItems: 'center',
    justifyContent: 'center',
  },
  centered: { textAlign: 'center' },
});
