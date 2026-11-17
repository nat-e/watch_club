import {useMutation, useQueryClient} from '@tanstack/react-query';
import {createFileRoute, redirect, useNavigate} from '@tanstack/react-router';
import {getInstanceOptions, loginMutation} from '@watchclub/api';
import {currentUserQuery, setCurrentUser} from '@watchclub/core/accounts/current-user';
import {useSignInFormOptions} from '@watchclub/core/accounts/sign-in';
import {useTranslation} from 'react-i18next';
import {useAppForm} from '@/components/forms/form';
import {Card, CardContent, CardHeader} from '@/components/ui/card';
import {sitePath} from '@/lib/site-path';

interface SignInSearch {
  /** The page that sent the visitor to sign in, where they go back afterwards */
  // biome-ignore lint/style/useNamingConvention: URL parameters are snake_case
  return_to?: string;
}

export const Route = createFileRoute('/_signed-out/sign-in')({
  // biome-ignore lint/style/useNamingConvention: URL parameters are snake_case
  validateSearch: (search): SignInSearch => ({return_to: sitePath(search.return_to)}),
  beforeLoad: async ({context, search}) => {
    const [instance, user] = await Promise.all([
      context.queryClient.ensureQueryData(getInstanceOptions()),
      context.queryClient.ensureQueryData(currentUserQuery),
    ]);
    if (instance.needs_setup) {
      throw redirect({to: '/setup'});
    }
    if (user) {
      throw redirect({href: search.return_to ?? '/'});
    }
  },
  component: SignIn,
});

function SignIn() {
  const {t} = useTranslation('core');
  const {return_to} = Route.useSearch();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const login = useMutation(loginMutation());
  const form = useAppForm(
    useSignInFormOptions(async credentials => {
      const user = await login.mutateAsync({body: credentials});
      await setCurrentUser(queryClient, user);
      await navigate({href: return_to ?? '/'});
    }),
  );

  return (
    <Card>
      <CardHeader>
        <h1 className="font-heading text-xl font-semibold">{t($ => $.core.signIn.title)}</h1>
      </CardHeader>
      <CardContent>
        <form.AppForm>
          <form.Form className="flex flex-col gap-6">
            <form.Field name="username">
              {field => (
                <field.TextField
                  label={t($ => $.core.user.username)}
                  autoComplete="username"
                  autoFocus
                />
              )}
            </form.Field>
            <form.Field name="password">
              {field => (
                <field.TextField
                  label={t($ => $.core.user.password)}
                  type="password"
                  autoComplete="current-password"
                />
              )}
            </form.Field>
            <form.FormError />
            <form.SubmitButton className="w-full">{t($ => $.core.signIn.submit)}</form.SubmitButton>
            <p className="text-sm text-muted-foreground">{t($ => $.core.signIn.forgotPassword)}</p>
          </form.Form>
        </form.AppForm>
      </CardContent>
    </Card>
  );
}
