import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** My Requests, where Users follow the Content they requested. Empty for now. */
export const Route = createFileRoute('/_shell/my-requests')({component: MyRequests});

function MyRequests() {
  const {t} = useTranslation('core');
  return <Page title={t($ => $.core.myRequests.title)} />;
}
