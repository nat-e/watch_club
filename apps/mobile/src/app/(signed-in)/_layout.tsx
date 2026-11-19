import {usePrefetchQuery} from '@tanstack/react-query';
import {getInstanceOptions} from '@watchclub/api';
import {NativeTabs} from 'expo-router/native-tabs';
import {useTranslation} from 'react-i18next';
import {useCSSVariable} from 'uniwind';

/**
 * The screens of signed-in Users: the app's sections, as the platform's own tabs with its own
 * symbols, SF Symbols on iOS and Material Symbols on Android. Each section stacks its screens under
 * a header with their name, and You holds the pages that have no tab.
 */
export default function SignedInLayout() {
  const {t} = useTranslation(['mobile', 'core']);
  // Before a screen shows the Instance Name, so it doesn't show the app's name first
  usePrefetchQuery(getInstanceOptions());
  const [card, foreground, mutedForeground, selected] = useCSSVariable([
    '--color-card',
    '--color-foreground',
    '--color-muted-foreground',
    '--color-selected',
  ]).map(value => String(value));

  return (
    <NativeTabs
      backgroundColor={card}
      tintColor={foreground}
      iconColor={{default: mutedForeground, selected: foreground}}
      labelStyle={{default: {color: mutedForeground}, selected: {color: foreground}}}
      indicatorColor={selected}
      labelVisibilityMode="labeled"
    >
      <NativeTabs.Trigger name="(home)">
        <NativeTabs.Trigger.Icon sf={{default: 'house', selected: 'house.fill'}} md="home" />
        <NativeTabs.Trigger.Label>{t($ => $.core.home.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(browse)">
        <NativeTabs.Trigger.Icon
          sf={{default: 'movieclapper', selected: 'movieclapper.fill'}}
          md="movie"
        />
        <NativeTabs.Trigger.Label>{t($ => $.core.browse.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(playlists)">
        <NativeTabs.Trigger.Icon sf="list.bullet" md="list" />
        <NativeTabs.Trigger.Label>{t($ => $.core.playlists.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(inbox)">
        <NativeTabs.Trigger.Icon sf={{default: 'tray', selected: 'tray.fill'}} md="inbox" />
        <NativeTabs.Trigger.Label>{t($ => $.core.inbox.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(you)">
        <NativeTabs.Trigger.Icon
          sf={{default: 'person.crop.circle', selected: 'person.crop.circle.fill'}}
          md="account_circle"
        />
        <NativeTabs.Trigger.Label>{t($ => $.mobile.you.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
