import { MaterialCommunityIcons } from '@expo/vector-icons';
import { StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/hooks/useTheme';

/** A plain-language failure message shown in place, next to the action that failed. */
export function InlineError({ message }: { message: string }) {
  const { colors, radii, spacing, typography } = useTheme();

  return (
    <View
      accessibilityRole="alert"
      accessibilityLiveRegion="polite"
      style={[
        styles.box,
        {
          backgroundColor: colors.surfaceMuted,
          borderColor: colors.danger,
          borderRadius: radii.md,
          padding: spacing.md,
          gap: spacing.sm,
        },
      ]}
    >
      <MaterialCommunityIcons name="alert-circle-outline" size={22} color={colors.danger} />
      <Text style={[typography.body, styles.text, { color: colors.text }]}>{message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  box: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    borderWidth: 1,
  },
  text: { flexShrink: 1 },
});
