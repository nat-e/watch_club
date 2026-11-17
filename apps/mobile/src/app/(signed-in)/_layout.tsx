import Lucide from '@react-native-vector-icons/lucide';
import {VectorIcon} from 'expo-router';
import {NativeTabs} from 'expo-router/native-tabs';
import {useTranslation} from 'react-i18next';
import {useCSSVariable} from 'uniwind';

/**
 * The screens of signed-in Users: the app's sections, as the platform's own tabs with the web app's
 * Lucide icons. Each section stacks its screens under a header with their name, and You holds the
 * pages that have no tab.
 */
export default function SignedInLayout() {
  const {t} = useTranslation(['mobile', 'core']);
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
        <NativeTabs.Trigger.Icon src={<VectorIcon family={Lucide} name="house" />} />
        <NativeTabs.Trigger.Label>{t($ => $.core.home.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(browse)">
        <NativeTabs.Trigger.Icon src={<VectorIcon family={Lucide} name="clapperboard" />} />
        <NativeTabs.Trigger.Label>{t($ => $.core.browse.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(playlists)">
        <NativeTabs.Trigger.Icon src={<VectorIcon family={Lucide} name="list" />} />
        <NativeTabs.Trigger.Label>{t($ => $.core.playlists.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(inbox)">
        <NativeTabs.Trigger.Icon src={<VectorIcon family={Lucide} name="inbox" />} />
        <NativeTabs.Trigger.Label>{t($ => $.core.inbox.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="(you)">
        <NativeTabs.Trigger.Icon src={<VectorIcon family={Lucide} name="circle-user-round" />} />
        <NativeTabs.Trigger.Label>{t($ => $.mobile.you.title)}</NativeTabs.Trigger.Label>
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
