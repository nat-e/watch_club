import {createFileRoute} from '@tanstack/react-router';
import {invitationsQuery} from '@watchclub/core/accounts/invitations';
import {usersQuery} from '@watchclub/core/accounts/users';
import {useInstanceName} from '@watchclub/core/instance';
import {useTranslation} from 'react-i18next';
import {Invitations, InviteFriendsButton} from '@/components/accounts/invitations';
import {UsersTable} from '@/components/accounts/users-table';
import {Page} from '@/components/layouts/page';

/** Users, where the Instance Administrator invites friends and manages the Users. */
export const Route = createFileRoute('/_shell/_admin/admin/users')({
  loader: ({context}) =>
    Promise.all([
      context.queryClient.ensureQueryData(invitationsQuery),
      context.queryClient.ensureQueryData(usersQuery),
    ]),
  component: Users,
});

function Users() {
  const {t} = useTranslation('web');
  const instanceName = useInstanceName();
  return (
    <Page title={t($ => $.web.users.title)}>
      <p className="max-w-readable leading-7 text-muted-foreground">
        {t($ => $.web.users.description, {name: instanceName})}
      </p>
      <Invitations />
      <div className="flex flex-col gap-4">
        <div className="flex justify-end">
          <InviteFriendsButton />
        </div>
        <UsersTable />
      </div>
    </Page>
  );
}
