import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';

/** Home's screens, under a header with their name. */
export default function HomeLayout() {
  const {t} = useTranslation('core');

  return (
    <Stack>
      <Stack.Screen name="index" options={{title: t($ => $.core.home.title)}} />
    </Stack>
  );
}
