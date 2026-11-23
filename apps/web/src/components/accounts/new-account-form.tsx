import type {PasswordError, UsernameError} from '@watchclub/api';
import {PASSWORD_MIN_LENGTH, usePasswordProblemMessage} from '@watchclub/core/accounts/passwords';
import {useTranslation} from 'react-i18next';
import {useAppForm} from '@/components/forms/form';

/** The username and password of a new account. */
export interface NewAccount {
  username: string;
  password: string;
}

/** The first problem the API finds with a new account's username or password. */
type NewAccountProblem =
  | {code: 'invalid_username'; reason: UsernameError}
  | {code: 'invalid_password'; reason: PasswordError}
  | {code: 'username_taken'};

/**
 * The form that creates an account, on Setup and with an Invitation: a username, and a password
 * typed twice. `createAccount` sends them, and returns the API's problem with them, or null once
 * the account is created or the page handled the failure itself. It throws on other failures, which
 * the form reports.
 */
export function NewAccountForm({
  createAccount,
}: {
  createAccount: (account: NewAccount) => Promise<NewAccountProblem | null>;
}) {
  const {t} = useTranslation(['web', 'core']);
  const passwordProblemMessage = usePasswordProblemMessage();

  function usernameMessage(problem: UsernameError): string {
    switch (problem.code) {
      case 'missing':
        return t($ => $.web.newAccount.chooseUsername);
      case 'too_short':
        return t($ => $.web.newAccount.usernameTooShort, {min: problem.min});
      case 'too_long':
        return t($ => $.web.newAccount.usernameTooLong, {max: problem.max});
      case 'invalid_characters':
        return t($ => $.web.newAccount.usernameCharacters);
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
            errors.fields.passwordConfirmation = t($ => $.core.password.passwordsDiffer);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      let problem: NewAccountProblem | null;
      try {
        problem = await createAccount({username: value.username, password: value.password});
      } catch {
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      if (problem === null) {
        return null;
      }
      switch (problem.code) {
        case 'invalid_username':
          return createValidationError({fields: {username: usernameMessage(problem.reason)}});
        case 'invalid_password':
          return createValidationError({
            fields: {password: passwordProblemMessage(problem.reason)},
          });
        case 'username_taken':
          return createValidationError({
            fields: {username: t($ => $.web.newAccount.usernameTaken)},
          });
      }
    },
  });

  return (
    <form.AppForm>
      <form.Form className="flex flex-col gap-6">
        <form.Field name="username">
          {field => (
            <field.TextField
              label={t($ => $.core.user.username)}
              hint={t($ => $.web.newAccount.usernameHint)}
              autoComplete="username"
              autoFocus
            />
          )}
        </form.Field>
        <form.Field name="password">
          {field => (
            <field.TextField
              label={t($ => $.core.user.password)}
              hint={t($ => $.core.password.hint, {min: PASSWORD_MIN_LENGTH})}
              type="password"
              autoComplete="new-password"
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
        <form.SubmitButton className="w-full">{t($ => $.web.newAccount.submit)}</form.SubmitButton>
      </form.Form>
    </form.AppForm>
  );
}
