import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** Browse, where Users look through the Library. Empty for now. */
export const Route = createFileRoute('/_shell/browse')({component: Browse});

function Browse() {
  const {t} = useTranslation('core');
  return <Page title={t($ => $.core.browse.title)} />;
}
