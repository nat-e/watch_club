import {useRouter} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {Text} from 'react-native';
import {Button} from '@/components/button';
import {Screen} from '@/components/screen';

/**
 * The screen in place of one that doesn't exist, as when a link to the app is wrong, with a way
 * home.
 */
export default function NotFound() {
  const {t} = useTranslation('core');
  const router = useRouter();

  return (
    <Screen>
      <Text
        accessibilityRole="header"
        className="text-center text-3xl font-semibold text-foreground"
      >
        {t($ => $.core.notFound.title)}
      </Text>
      <Text className="text-center text-base text-muted-foreground">
        {t($ => $.core.notFound.description)}
      </Text>
      <Button
        onPress={() => {
          router.replace('/');
        }}
      >
        {t($ => $.core.notFound.goHome)}
      </Button>
    </Screen>
  );
}
