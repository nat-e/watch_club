import {useQueryClient} from '@tanstack/react-query';
import {createFileRoute, redirect, useNavigate} from '@tanstack/react-router';
import {
  createInstanceAdministrator,
  getInstanceOptions,
  type PasswordProblem,
  UnexpectedError,
  type UsernameProblem,
} from '@watchclub/api';
import {setCurrentUser} from '@watchclub/core/accounts/current-user';
import {negotiateLocale} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {useAppForm} from '@/components/form';
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
  const {t} = useTranslation(['web', 'core']);
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

  function usernameMessage(problem: UsernameProblem): string {
    switch (problem.code) {
      case 'missing':
        return t($ => $.web.setup.chooseUsername);
      case 'too_short':
        return t($ => $.web.setup.usernameTooShort, {min: problem.min});
      case 'too_long':
        return t($ => $.web.setup.usernameTooLong, {max: problem.max});
      case 'invalid_characters':
        return t($ => $.web.setup.usernameCharacters);
    }
  }

  function passwordMessage(problem: PasswordProblem): string {
    switch (problem.code) {
      case 'missing':
        return t($ => $.web.setup.choosePassword);
      case 'too_short':
        return t($ => $.web.setup.passwordTooShort, {min: problem.min});
    }
  }

  const form = useAppForm({
    defaultValues: {username: '', password: '', passwordConfirmation: ''},
    validators: [
      {
        // On submit only, as the visitor may not have typed the confirmation yet
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          if (value.passwordConfirmation !== value.password) {
            errors.fields.passwordConfirmation = t($ => $.web.setup.passwordsDiffer);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      const locale = negotiateLocale(navigator.languages);
      const {data: user, error} = await createInstanceAdministrator({
        body: {username: value.username, password: value.password, locale},
      });
      if (user) {
        markSetupDone();
        await setCurrentUser(queryClient, user);
        await navigate({to: '/'});
        return null;
      }
      if (error instanceof UnexpectedError) {
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      switch (error.code) {
        case 'invalid_fields':
          return createValidationError({
            fields: {
              username: error.username && usernameMessage(error.username),
              password: error.password && passwordMessage(error.password),
            },
          });
        // Someone else finished Setup in the meantime
        case 'instance_administrator_already_exists':
          markSetupDone();
          await navigate({to: '/'});
          return null;
        case 'invalid_request':
        case 'internal_error':
          return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
    },
  });

  return (
    <Card>
      <CardHeader className="gap-3">
        <h1 className="font-heading text-xl font-semibold">{t($ => $.web.setup.title)}</h1>
        <CardDescription>{t($ => $.web.setup.administratorAccount)}</CardDescription>
        <CardDescription>{t($ => $.web.setup.keepItToYourself)}</CardDescription>
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
                  autoComplete="new-password"
                />
              )}
            </form.Field>
            <form.Field name="passwordConfirmation">
              {field => (
                <field.TextField
                  label={t($ => $.web.setup.confirmPassword)}
                  type="password"
                  autoComplete="new-password"
                />
              )}
            </form.Field>
            <form.FormError />
            <form.SubmitButton className="w-full">{t($ => $.web.setup.submit)}</form.SubmitButton>
          </form.Form>
        </form.AppForm>
      </CardContent>
    </Card>
  );
}
