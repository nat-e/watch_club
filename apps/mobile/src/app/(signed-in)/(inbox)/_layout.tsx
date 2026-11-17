import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

/** The Inbox's screens, under a header with their name. */
export default function InboxLayout() {
  const {t} = useTranslation('core');

  return (
    <Stack>
      <Stack.Screen name="inbox" options={{title: t($ => $.core.inbox.title)}} />
    </Stack>
  );
}
