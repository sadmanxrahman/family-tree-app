import type { ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useTheme } from '@/hooks/useTheme';

type Props = {
  children: ReactNode;
  /** Vertically centre short content, e.g. a status message. */
  centered?: boolean;
};

/**
 * Standard screen shell: themed background, safe areas, keyboard avoidance, and scrolling
 * so nothing is cut off at the largest accessibility text sizes.
 */
export function Screen({ children, centered = false }: Props) {
  const { colors, spacing } = useTheme();

  return (
    <SafeAreaView style={[styles.flex, { backgroundColor: colors.background }]}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={[
            styles.content,
            { padding: spacing.xl, gap: spacing.lg },
            centered && styles.centered,
          ]}
        >
          {children}
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  content: { flexGrow: 1 },
  centered: { justifyContent: 'center' },
});
