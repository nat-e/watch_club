import {useRouter} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {StatusScreen} from '@/components/status-screen';

/**
 * The screen in place of one that doesn't exist, as when a link to the app is wrong, with a way
 * home.
 */
export default function NotFound() {
  const {t} = useTranslation('core');
  const router = useRouter();

  return (
    <StatusScreen
      title={t($ => $.core.notFound.title)}
      description={t($ => $.core.notFound.description)}
      actions={[
        {
          label: t($ => $.core.notFound.goHome),
          onPress: () => {
            router.replace('/');
          },
        },
      ]}
    />
  );
}
