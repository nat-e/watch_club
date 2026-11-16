import {Stack} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {useCSSVariable} from 'uniwind';

/** The screens of signed-in Users, under a header with the screen's name. */
export default function SignedInLayout() {
  const {t} = useTranslation('core');
  const [background, card, foreground] = useCSSVariable([
    '--color-background',
    '--color-card',
    '--color-foreground',
  ]).map(value => String(value));

  return (
    <Stack
      screenOptions={{
        headerStyle: {backgroundColor: card},
        headerTintColor: foreground,
        contentStyle: {backgroundColor: background},
      }}
    >
      <Stack.Screen name="index" options={{title: t($ => $.core.home.title)}} />
      <Stack.Screen name="settings" options={{title: t($ => $.core.settings.title)}} />
    </Stack>
  );
}
