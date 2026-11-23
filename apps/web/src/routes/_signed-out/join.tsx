import {useQueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {createFileRoute, redirect, useNavigate} from '@tanstack/react-router';
import {redeemInvitation} from '@watchclub/api';
import {currentUserQuery, setCurrentUser} from '@watchclub/core/accounts/current-user';
import {invitationCheckQuery} from '@watchclub/core/accounts/invitations';
import {useInstanceName} from '@watchclub/core/instance';
import {negotiateLocale} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {type NewAccount, NewAccountForm} from '@/components/accounts/new-account-form';
import {Card, CardContent, CardDescription, CardHeader} from '@/components/ui/card';

interface JoinSearch {
  /** The Invitation's code, which its link carries */
  code?: string;
}

/**
 * The page of an Invitation's link, where a new person creates their account. Users who are signed
 * in already go home: they never redeem an Invitation.
 */
export const Route = createFileRoute('/_signed-out/join')({
  validateSearch: (search): JoinSearch => ({
    code: typeof search.code === 'string' ? search.code : undefined,
  }),
  beforeLoad: async ({context}) => {
    const user = await context.queryClient.ensureQueryData(currentUserQuery);
    if (user) {
      throw redirect({to: '/'});
    }
  },
  loaderDeps: ({search}) => ({code: search.code}),
  loader: async ({context, deps}) => {
    if (deps.code !== undefined) {
      await context.queryClient.ensureQueryData(invitationCheckQuery(deps.code));
    }
  },
  component: Join,
});

function Join() {
  const {code} = Route.useSearch();
  return code === undefined ? <InvitationNoLongerWorks /> : <Invitation code={code} />;
}

/** The Invitation, with the form that redeems it, unless it can't be redeemed anymore. */
function Invitation({code}: {code: string}) {
  const {t} = useTranslation('web');
  const instanceName = useInstanceName();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const {data: check} = useSuspenseQuery(invitationCheckQuery(code));

  async function createAccount(account: NewAccount) {
    const locale = negotiateLocale(navigator.languages);
    const {data: user, error} = await redeemInvitation({body: {...account, code, locale}});
    if (user) {
      await setCurrentUser(queryClient, user);
      await navigate({to: '/'});
      return null;
    }
    switch (error.code) {
      case 'invalid_username':
      case 'invalid_password':
      case 'username_taken':
        return error;
      // It expired, or others used it up, since the page opened
      case 'invitation_not_redeemable':
        queryClient.setQueryData(invitationCheckQuery(code).queryKey, {redeemable: false});
        return null;
      case 'invalid_request':
      case 'payload_too_large':
      case 'unsupported_media_type':
      case 'internal_error':
        throw error;
    }
  }

  if (!check.redeemable) {
    return <InvitationNoLongerWorks />;
  }
  return (
    <Card>
      <CardHeader className="gap-3">
        <h1 className="font-heading text-xl font-semibold">
          {t($ => $.web.join.title, {name: instanceName})}
        </h1>
        <CardDescription>{t($ => $.web.join.description)}</CardDescription>
      </CardHeader>
      <CardContent>
        <NewAccountForm createAccount={createAccount} />
      </CardContent>
    </Card>
  );
}

/** The page of an Invitation that expired, was used up or deleted, or never existed. */
function InvitationNoLongerWorks() {
  const {t} = useTranslation('web');
  return (
    <Card>
      <CardHeader className="gap-3">
        <h1 className="font-heading text-xl font-semibold">{t($ => $.web.join.noLongerWorks)}</h1>
        <CardDescription>{t($ => $.web.join.askForNewLink)}</CardDescription>
      </CardHeader>
    </Card>
  );
}
