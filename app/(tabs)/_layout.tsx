import { MaterialCommunityIcons } from '@expo/vector-icons';
import Tabs from 'expo-router/js-tabs';
import type { ComponentProps } from 'react';
import type { ColorValue } from 'react-native';

import { useTheme } from '@/hooks/useTheme';
import { t } from '@/lib/i18n';

type IconName = ComponentProps<typeof MaterialCommunityIcons>['name'];

function tabIcon(name: IconName) {
  function TabIcon({ color, size }: { color: ColorValue; size: number }) {
    return <MaterialCommunityIcons name={name} color={color} size={size} />;
  }
  return TabIcon;
}

export default function TabsLayout() {
  const { colors, typography } = useTheme();

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: { backgroundColor: colors.surface, borderTopColor: colors.border },
        headerStyle: { backgroundColor: colors.background },
        headerTintColor: colors.text,
        headerTitleStyle: { fontFamily: typography.title.fontFamily },
        headerShadowVisible: false,
      }}
    >
      <Tabs.Screen
        name="tree"
        options={{
          title: t('tabs.tree'),
          tabBarAccessibilityLabel: t('tabs.treeA11y'),
          tabBarIcon: tabIcon('family-tree'),
        }}
      />
      <Tabs.Screen
        name="feed"
        options={{
          title: t('tabs.feed'),
          tabBarAccessibilityLabel: t('tabs.feedA11y'),
          tabBarIcon: tabIcon('image-multiple-outline'),
        }}
      />
      <Tabs.Screen
        name="map"
        options={{
          title: t('tabs.map'),
          tabBarAccessibilityLabel: t('tabs.mapA11y'),
          tabBarIcon: tabIcon('map-outline'),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: t('tabs.profile'),
          tabBarAccessibilityLabel: t('tabs.profileA11y'),
          tabBarIcon: tabIcon('account-circle-outline'),
        }}
      />
    </Tabs>
  );
}
