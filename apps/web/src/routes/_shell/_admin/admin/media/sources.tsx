import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/page';

/** Media sources, where the Instance Administrator manages where Media comes from. Empty for now. */
export const Route = createFileRoute('/_shell/_admin/admin/media/sources')({
  component: MediaSources,
});

function MediaSources() {
  const {t} = useTranslation('web');
  return <Page title={t($ => $.web.mediaSources.title)} />;
}
