import {useMutation, useQueryClient} from '@tanstack/react-query';
import {createFileRoute, redirect, useNavigate} from '@tanstack/react-router';
import {getInstanceOptions, loginMutation} from '@watchclub/api';
import {currentUserQuery, signedIn} from '@watchclub/core/accounts/session';
import {useSignInForm} from '@watchclub/core/accounts/sign-in';
import type {FormEvent} from 'react';
import {useTranslation} from 'react-i18next';
import {SomethingWentWrong} from '@/components/something-went-wrong';
import {TextField} from '@/components/text-field';
import {Button} from '@/components/ui/button';
import {Card, CardContent, CardHeader} from '@/components/ui/card';

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

/** Returns the value if it's a path on this site, so a link can't send Users to another one. */
function sitePath(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  const isSitePath = value.startsWith('/') && !value.startsWith('//') && !value.includes('\\');
  return isSitePath ? value : undefined;
}

function SignIn() {
  const {t} = useTranslation('core');
  const {return_to} = Route.useSearch();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const signIn = useMutation({
    ...loginMutation(),
    onSuccess: async user => {
      await signedIn(queryClient, user);
      await navigate({href: return_to ?? '/'});
    },
  });
  const form = useSignInForm(signIn);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    form.submit(String(fields.get('username')), String(fields.get('password')));
  }

  return (
    <Card>
      <CardHeader>
        <h1 className="font-heading text-xl font-semibold">{t($ => $.core.signIn.title)}</h1>
      </CardHeader>
      <CardContent>
        {/* The server's errors show under the fields, rather than the browser's */}
        <form noValidate onSubmit={submit} className="flex flex-col gap-6">
          <TextField
            label={t($ => $.core.user.username)}
            error={form.usernameError}
            name="username"
            autoComplete="username"
            autoFocus
          />
          <TextField
            label={t($ => $.core.user.password)}
            error={form.passwordError}
            name="password"
            type="password"
            autoComplete="current-password"
          />
          {form.failed && <SomethingWentWrong />}
          <Button type="submit" className="w-full" disabled={signIn.isPending}>
            {t($ => $.core.signIn.submit)}
          </Button>
          <p className="text-sm text-muted-foreground">{t($ => $.core.signIn.forgotPassword)}</p>
        </form>
      </CardContent>
    </Card>
  );
}
