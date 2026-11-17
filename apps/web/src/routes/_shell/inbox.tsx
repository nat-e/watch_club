import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** The Inbox, where Users see their Conversations. Empty for now. */
export const Route = createFileRoute('/_shell/inbox')({component: Inbox});

function Inbox() {
  const {t} = useTranslation('core');
  return <Page title={t($ => $.core.inbox.title)} />;
}
