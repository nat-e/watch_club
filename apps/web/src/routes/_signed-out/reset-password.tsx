import {useSuspenseQuery} from '@tanstack/react-query';
import {createFileRoute, Link, useNavigate} from '@tanstack/react-router';
import {
  PASSWORD_MIN_LENGTH,
  passwordResetLinkQuery,
  useResetPasswordFormOptions,
} from '@watchclub/core/accounts/passwords';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {useAppForm} from '@/components/forms/form';
import {TextField} from '@/components/forms/text-field';
import {buttonVariants} from '@/components/ui/button';
import {Card, CardContent, CardDescription, CardHeader} from '@/components/ui/card';
import {cn} from '@/lib/utils';

interface ResetPasswordSearch {
  /** The token of the Password Reset Link, which the link carries */
  token?: string;
}

/**
 * The page of a Password Reset Link, where a User who forgot their password chooses a new one, then
 * signs in with it. It also works for a browser that's signed in, as it may be the User's, who
 * can't change their password in Settings without the current one, and signs it out.
 */
export const Route = createFileRoute('/_signed-out/reset-password')({
  validateSearch: (search): ResetPasswordSearch => ({
    token: typeof search.token === 'string' ? search.token : undefined,
  }),
  loaderDeps: ({search}) => ({token: search.token}),
  loader: async ({context, deps}) => {
    if (deps.token !== undefined) {
      await context.queryClient.ensureQueryData(passwordResetLinkQuery(deps.token));
    }
  },
  component: ResetPassword,
});

function ResetPassword() {
  const {token} = Route.useSearch();
  return token === undefined ? <LinkNoLongerWorks /> : <PasswordReset token={token} />;
}

/** The form that sets the User's new password, unless the link no longer works. */
function PasswordReset({token}: {token: string}) {
  const {data: link} = useSuspenseQuery(passwordResetLinkQuery(token));
  return link.username === null ? (
    <LinkNoLongerWorks />
  ) : (
    <NewPasswordForm token={token} username={link.username} />
  );
}

/** The form with the User's new password, typed twice, after which they go sign in with it. */
function NewPasswordForm({token, username}: {token: string; username: string}) {
  const {t} = useTranslation(['web', 'core']);
  const navigate = useNavigate();
  const form = useAppForm(
    useResetPasswordFormOptions(token, async () => {
      toast.success(t($ => $.web.resetPassword.saved));
      await navigate({to: '/sign-in'});
    }),
  );

  return (
    <Card>
      <CardHeader>
        <h1 className="font-heading text-xl font-semibold">{t($ => $.web.resetPassword.title)}</h1>
      </CardHeader>
      <CardContent>
        <form.AppForm>
          <form.Form className="flex flex-col gap-6">
            {/* Whose password it is, which password managers also read to save the new one */}
            <TextField
              label={t($ => $.core.user.username)}
              value={username}
              readOnly
              autoComplete="username"
            />
            <form.Field name="password">
              {field => (
                <field.TextField
                  label={t($ => $.core.password.newPassword)}
                  hint={t($ => $.core.password.hint, {min: PASSWORD_MIN_LENGTH})}
                  type="password"
                  autoComplete="new-password"
                  autoFocus
                />
              )}
            </form.Field>
            <form.Field name="passwordConfirmation">
              {field => (
                <field.TextField
                  label={t($ => $.core.password.confirmPassword)}
                  type="password"
                  autoComplete="new-password"
                />
              )}
            </form.Field>
            <form.FormError />
            <form.SubmitButton className="w-full">
              {t($ => $.web.resetPassword.submit)}
            </form.SubmitButton>
          </form.Form>
        </form.AppForm>
      </CardContent>
    </Card>
  );
}

/** The page of a Password Reset Link that expired, was used or replaced, or never existed. */
function LinkNoLongerWorks() {
  const {t} = useTranslation('web');
  return (
    <Card>
      <CardHeader className="gap-3">
        <h1 className="font-heading text-xl font-semibold">
          {t($ => $.web.resetPassword.noLongerWorks)}
        </h1>
        <CardDescription>{t($ => $.web.resetPassword.askForNewLink)}</CardDescription>
      </CardHeader>
      <CardContent>
        <Link to="/sign-in" className={cn(buttonVariants(), 'w-full')}>
          {t($ => $.web.resetPassword.backToSignIn)}
        </Link>
      </CardContent>
    </Card>
  );
}
