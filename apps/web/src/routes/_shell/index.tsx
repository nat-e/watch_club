import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** Home, where signed-in Users land. Empty for now. */
export const Route = createFileRoute('/_shell/')({component: Home});

function Home() {
  const {t} = useTranslation('core');
  return <Page title={t($ => $.core.home.title)} />;
}
