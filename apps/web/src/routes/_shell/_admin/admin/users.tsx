import {createFileRoute} from '@tanstack/react-router';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';

/** Users, where the Instance Administrator manages the Users. Empty for now. */
export const Route = createFileRoute('/_shell/_admin/admin/users')({component: Users});

function Users() {
  const {t} = useTranslation('web');
  return <Page title={t($ => $.web.users.title)} />;
}
