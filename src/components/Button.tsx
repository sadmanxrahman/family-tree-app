import { MaterialCommunityIcons } from '@expo/vector-icons';
import type { ComponentProps } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/hooks/useTheme';

type Props = {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'plain';
  icon?: ComponentProps<typeof MaterialCommunityIcons>['name'];
  loading?: boolean;
  disabled?: boolean;
  /** Defaults to the label. Set when the label alone is ambiguous out of context. */
  accessibilityLabel?: string;
  accessibilityHint?: string;
};

export function Button({
  label,
  onPress,
  variant = 'primary',
  icon,
  loading = false,
  disabled = false,
  accessibilityLabel,
  accessibilityHint,
}: Props) {
  const { colors, radii, spacing, typography } = useTheme();
  const inactive = disabled || loading;

  const palette = {
    primary: { background: colors.primary, foreground: colors.onPrimary, border: colors.primary },
    secondary: { background: colors.surface, foreground: colors.text, border: colors.border },
    plain: { background: 'transparent', foreground: colors.primary, border: 'transparent' },
  }[variant];

  return (
    <Pressable
      onPress={onPress}
      disabled={inactive}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: inactive, busy: loading }}
      style={({ pressed }) => [
        styles.base,
        {
          backgroundColor: palette.background,
          borderColor: palette.border,
          borderRadius: radii.md,
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.md,
          opacity: inactive ? 0.55 : pressed ? 0.8 : 1,
        },
      ]}
    >
      <View style={styles.content}>
        {loading ? (
          <ActivityIndicator color={palette.foreground} />
        ) : (
          icon && <MaterialCommunityIcons name={icon} size={22} color={palette.foreground} />
        )}
        <Text style={[typography.bodyStrong, styles.label, { color: palette.foreground }]}>
          {label}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    // Above the 44pt minimum (CLAUDE.md rule 9); primary actions deserve a larger target.
    minHeight: 52,
    borderWidth: 1,
    justifyContent: 'center',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  label: {
    textAlign: 'center',
    flexShrink: 1,
  },
});
