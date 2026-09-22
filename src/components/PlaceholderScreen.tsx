import { MaterialCommunityIcons } from '@expo/vector-icons';
import type { ComponentProps } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/hooks/useTheme';

type Props = {
  icon: ComponentProps<typeof MaterialCommunityIcons>['name'];
  title: string;
  body: string;
};

/** Temporary content for tabs whose feature has not been built yet. */
export function PlaceholderScreen({ icon, title, body }: Props) {
  const { colors, spacing, radii, typography } = useTheme();

  return (
    // ScrollView so the text never gets cut off at the largest accessibility font sizes.
    <ScrollView
      style={{ backgroundColor: colors.background }}
      contentContainerStyle={[styles.container, { padding: spacing.xl }]}
    >
      <View
        style={[
          styles.iconCircle,
          {
            backgroundColor: colors.surfaceMuted,
            borderRadius: radii.pill,
            marginBottom: spacing.xl,
          },
        ]}
        accessible={false}
      >
        <MaterialCommunityIcons name={icon} size={48} color={colors.primary} />
      </View>
      <Text
        accessibilityRole="header"
        style={[
          typography.title,
          styles.centered,
          { color: colors.text, marginBottom: spacing.sm },
        ]}
      >
        {title}
      </Text>
      <Text style={[typography.body, styles.centered, { color: colors.textMuted }]}>{body}</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconCircle: {
    width: 96,
    height: 96,
    alignItems: 'center',
    justifyContent: 'center',
  },
  centered: {
    textAlign: 'center',
    maxWidth: 360,
  },
});
