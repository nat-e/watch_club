import {Tabs} from 'expo-router/js-tabs';
import {
  CircleUserRoundIcon,
  ClapperboardIcon,
  HouseIcon,
  InboxIcon,
  ListIcon,
  type LucideIcon,
} from 'lucide-react-native';
import {useTranslation} from 'react-i18next';
import type {ColorValue} from 'react-native';

/**
 * The app's sections, as tabs at the bottom of the screen, under a header with the section's name.
 * You holds the pages that have no tab.
 */
export default function TabsLayout() {
  const {t} = useTranslation(['mobile', 'core']);

  return (
    <Tabs>
      <Tabs.Screen
        name="index"
        options={{title: t($ => $.core.home.title), tabBarIcon: tabIcon(HouseIcon)}}
      />
      <Tabs.Screen
        name="browse"
        options={{title: t($ => $.core.browse.title), tabBarIcon: tabIcon(ClapperboardIcon)}}
      />
      <Tabs.Screen
        name="playlists"
        options={{title: t($ => $.core.playlists.title), tabBarIcon: tabIcon(ListIcon)}}
      />
      <Tabs.Screen
        name="inbox"
        options={{title: t($ => $.core.inbox.title), tabBarIcon: tabIcon(InboxIcon)}}
      />
      <Tabs.Screen
        name="you"
        options={{title: t($ => $.mobile.you.title), tabBarIcon: tabIcon(CircleUserRoundIcon)}}
      />
    </Tabs>
  );
}

/** Returns the function that draws `Icon` in a tab, in the tab's color. */
function tabIcon(Icon: LucideIcon) {
  return ({color, size}: {color: ColorValue; size: number}) => <Icon color={color} size={size} />;
}
