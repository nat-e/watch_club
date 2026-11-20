import {useQueryClient} from '@tanstack/react-query';
import {createFileRoute, redirect, useNavigate} from '@tanstack/react-router';
import {createInstanceAdministrator, getInstanceOptions} from '@watchclub/api';
import {setCurrentUser} from '@watchclub/core/accounts/current-user';
import {negotiateLocale} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {type NewAccount, NewAccountForm} from '@/components/accounts/new-account-form';
import {Card, CardContent, CardDescription, CardHeader} from '@/components/ui/card';

/** Setup, where a new WatchClub's first visitor creates the Instance Administrator. */
export const Route = createFileRoute('/_signed-out/setup')({
  beforeLoad: async ({context}) => {
    const instance = await context.queryClient.ensureQueryData(getInstanceOptions());
    if (!instance.needs_setup) {
      throw redirect({to: '/'});
    }
  },
  component: Setup,
});

function Setup() {
  const {t} = useTranslation('web');
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  /** Marks Setup as done, so the pages stop sending visitors here. */
  function markSetupDone() {
    queryClient.setQueryData(
      getInstanceOptions().queryKey,
      // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
      instance => instance && {...instance, needs_setup: false},
    );
  }

  async function createAccount(account: NewAccount) {
    const locale = negotiateLocale(navigator.languages);
    const {data: user, error} = await createInstanceAdministrator({body: {...account, locale}});
    if (user) {
      markSetupDone();
      await setCurrentUser(queryClient, user);
      await navigate({to: '/'});
      return null;
    }
    switch (error.code) {
      case 'invalid_username':
      case 'invalid_password':
        return error;
      // Someone else finished Setup in the meantime
      case 'instance_administrator_already_exists':
        markSetupDone();
        await navigate({to: '/'});
        return null;
      case 'invalid_request':
      case 'internal_error':
        throw error;
    }
  }

  return (
    <Card>
      <CardHeader className="gap-3">
        <h1 className="font-heading text-xl font-semibold">{t($ => $.web.setup.title)}</h1>
        <CardDescription>{t($ => $.web.setup.administratorAccount)}</CardDescription>
        <CardDescription>{t($ => $.web.setup.keepItToYourself)}</CardDescription>
      </CardHeader>
      <CardContent>
        <NewAccountForm createAccount={createAccount} />
      </CardContent>
    </Card>
  );
}
