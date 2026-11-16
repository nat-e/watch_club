import {useMutation, useQueryClient} from '@tanstack/react-query';
import {createFileRoute, redirect, useNavigate} from '@tanstack/react-router';
import {
  type CreateInstanceAdministratorError,
  createInstanceAdministratorMutation,
  getInstanceOptions,
  hasCode,
  type PasswordProblem,
  UnexpectedError,
  type UsernameProblem,
} from '@watchclub/api';
import {signedIn} from '@watchclub/core/accounts/session';
import {negotiateLocale} from '@watchclub/core/l10n';
import {type FormEvent, useState} from 'react';
import {useTranslation} from 'react-i18next';
import {SomethingWentWrong} from '@/components/something-went-wrong';
import {TextField} from '@/components/text-field';
import {Button} from '@/components/ui/button';
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
  const [passwordsDiffer, setPasswordsDiffer] = useState(false);

  /** Records that WatchClub is set up, so the pages stop sending visitors here. */
  function setUpDone() {
    queryClient.setQueryData(
      getInstanceOptions().queryKey,
      // biome-ignore lint/style/useNamingConvention: the API uses snake_case field names
      instance => instance && {...instance, needs_setup: false},
    );
  }

  const setUp = useMutation({
    ...createInstanceAdministratorMutation(),
    onSuccess: async user => {
      setUpDone();
      await signedIn(queryClient, user);
      await navigate({to: '/'});
    },
    onError: async error => {
      // Someone else finished Setup in the meantime
      if (hasCode(error, 'instance_administrator_already_exists')) {
        setUpDone();
        await navigate({to: '/'});
      }
    },
  });

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const password = String(form.get('password'));
    const passwordsDiffer = form.get('password_confirmation') !== password;
    setPasswordsDiffer(passwordsDiffer);
    if (passwordsDiffer) {
      // Its errors were about values the visitor may have changed since
      setUp.reset();
    } else {
      const username = String(form.get('username'));
      const locale = negotiateLocale(navigator.languages);
      setUp.mutate({body: {username, password, locale}});
    }
  }

  /** Returns the problems with the fields that made Setup fail, if they did. */
  function fieldProblems(error: CreateInstanceAdministratorError | UnexpectedError) {
    if (error instanceof UnexpectedError) {
      return undefined;
    }
    switch (error.code) {
      case 'invalid_fields':
        return error;
      case 'instance_administrator_already_exists':
      case 'invalid_request':
      case 'internal_error':
        return undefined;
    }
  }

  const problems = setUp.error ? fieldProblems(setUp.error) : undefined;

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

  return (
    <Card>
      <CardHeader className="gap-3">
        <h1 className="font-heading text-xl font-semibold">{t($ => $.web.setup.title)}</h1>
        <CardDescription>{t($ => $.web.setup.administratorAccount)}</CardDescription>
        <CardDescription>{t($ => $.web.setup.keepItToYourself)}</CardDescription>
      </CardHeader>
      <CardContent>
        {/* The server's errors show under the fields, rather than the browser's */}
        <form noValidate onSubmit={submit} className="flex flex-col gap-6">
          <TextField
            label={t($ => $.core.user.username)}
            error={problems?.username ? usernameMessage(problems.username) : undefined}
            name="username"
            autoComplete="username"
            autoFocus
          />
          <TextField
            label={t($ => $.core.user.password)}
            error={problems?.password ? passwordMessage(problems.password) : undefined}
            name="password"
            type="password"
            autoComplete="new-password"
          />
          <TextField
            label={t($ => $.web.setup.confirmPassword)}
            error={passwordsDiffer ? t($ => $.web.setup.passwordsDiffer) : undefined}
            name="password_confirmation"
            type="password"
            autoComplete="new-password"
          />
          {setUp.isError && !problems && <SomethingWentWrong />}
          <Button type="submit" className="w-full" disabled={setUp.isPending}>
            {t($ => $.web.setup.submit)}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
