import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** The Media browser, where the Instance Administrator looks through the Media. Empty for now. */
export const Route = createFileRoute('/_shell/_admin/admin/media/')({component: MediaBrowser});

function MediaBrowser() {
  const {t} = useTranslation('web');
  return <Page title={t($ => $.web.mediaBrowser.title)} />;
}
