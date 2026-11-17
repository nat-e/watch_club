import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/page';

/** Instance settings, where the Instance Administrator sets up the instance. Empty for now. */
export const Route = createFileRoute('/_shell/_admin/admin/settings')({
  component: InstanceSettings,
});

function InstanceSettings() {
  const {t} = useTranslation('web');
  return <Page title={t($ => $.web.instanceSettings.title)} />;
}
