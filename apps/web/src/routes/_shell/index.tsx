import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';

/** Home, where signed-in Users land. Empty for now. */
export const Route = createFileRoute('/_shell/')({component: Home});

function Home() {
  const {t} = useTranslation('core');
  return <h1 className="font-heading text-2xl font-semibold">{t($ => $.core.home.title)}</h1>;
}
