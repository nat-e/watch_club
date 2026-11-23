/**
 * Passwords: the rules of a new password, which both apps show, the form that changes the User's
 * password in Settings, and the Password Reset Links that let a User who forgot theirs choose a new
 * one.
 */
import {formOptions} from '@tanstack/react-form';
import {mutationOptions, queryOptions, useMutation, useQueryClient} from '@tanstack/react-query';
import {
  type ChangePasswordError,
  changePassword,
  checkPasswordResetLinkOptions,
  hasCode,
  logout,
  type PasswordChange,
  type PasswordError,
  resetPassword,
} from '@watchclub/api';
import {useTranslation} from 'react-i18next';
import {forgetCurrentUser} from './current-user';

/** The fewest characters a password has, which its hint says */
export const PASSWORD_MIN_LENGTH = 8;

/** Returns the function that says, in the User's language, which rule a new password breaks. */
export function usePasswordProblemMessage(): (problem: PasswordError) => string {
  const {t} = useTranslation('core');
  return problem => {
    switch (problem.code) {
      case 'missing':
        return t($ => $.core.password.choosePassword);
      case 'too_short':
        return t($ => $.core.password.tooShort, {min: problem.min});
    }
  };
}

/** The API's refusal of the passwords, which the form shows under their fields. */
type PasswordChangeProblem = Extract<
  ChangePasswordError,
  {code: 'wrong_password' | 'invalid_password'}
>;

/**
 * The mutation that changes the User's password. It resolves to the API's problem with the
 * passwords, or null once the password changed, and fails otherwise, such as when the session
 * ended, which the query client handles.
 */
const changePasswordMutation = mutationOptions({
  mutationFn: async (change: PasswordChange): Promise<PasswordChangeProblem | null> => {
    const {error} = await changePassword({body: change});
    if (hasCode(error, 'wrong_password') || hasCode(error, 'invalid_password')) {
      return error;
    }
    if (error !== undefined) {
      throw error;
    }
    return null;
  },
});

/**
 * Returns the options of the form that changes the User's password, for each app's `useAppForm`:
 * their current password, and a new one typed twice. The form empties once the password changed,
 * and the API signed the User out on their other devices, then `onChanged` runs, such as to say so.
 */
export function useChangePasswordFormOptions(onChanged: () => void) {
  const {t} = useTranslation('core');
  const change = useMutation(changePasswordMutation);
  const passwordProblemMessage = usePasswordProblemMessage();
  return formOptions({
    defaultValues: {currentPassword: '', newPassword: '', passwordConfirmation: ''},
    validators: [
      {
        // On submit only, as the User may not have typed the confirmation yet
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          if (value.currentPassword === '') {
            errors.fields.currentPassword = t($ => $.core.password.enterCurrentPassword);
          }
          if (value.passwordConfirmation !== value.newPassword) {
            errors.fields.passwordConfirmation = t($ => $.core.password.passwordsDiffer);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, formApi, createValidationError}) => {
      let problem: PasswordChangeProblem | null;
      try {
        // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
        problem = await change.mutateAsync({
          current_password: value.currentPassword,
          new_password: value.newPassword,
        });
        // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
      } catch {
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      if (problem === null) {
        formApi.reset();
        onChanged();
        return null;
      }
      switch (problem.code) {
        case 'wrong_password':
          return createValidationError({
            fields: {currentPassword: t($ => $.core.password.wrongCurrentPassword)},
          });
        case 'invalid_password':
          return createValidationError({
            fields: {newPassword: passwordProblemMessage(problem.reason)},
          });
      }
    },
  });
}

/**
 * Returns the query that tells whose password the Password Reset Link with this token resets: their
 * username, or null once the link no longer works.
 */
export function passwordResetLinkQuery(token: string) {
  return queryOptions(checkPasswordResetLinkOptions({query: {token}}));
}

/**
 * Returns the options of the form that sets a new password with the Password Reset Link that has
 * this token, for each app's `useAppForm`: the new password, typed twice. Once it's saved, the API
 * has signed the User out everywhere, and this device is signed out too, even when another User was
 * signed in on it, so that it's ready for them to sign in: `onReset` then runs, such as to go sign
 * in. When the link stops working meanwhile, its query says so.
 */
export function useResetPasswordFormOptions(token: string, onReset: () => Promise<void>) {
  const {t} = useTranslation('core');
  const queryClient = useQueryClient();
  const passwordProblemMessage = usePasswordProblemMessage();
  return formOptions({
    defaultValues: {password: '', passwordConfirmation: ''},
    validators: [
      {
        // On submit only, as the User may not have typed the confirmation yet
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
      const {error} = await resetPassword({body: {token, password: value.password}});
      if (error === undefined) {
        // Succeeds when nobody is signed in on this device, such as when it was the User. When it
        // fails, the screens keep showing who's still signed in
        const signedOut = await logout();
        if (signedOut.error === undefined) {
          await forgetCurrentUser(queryClient);
        }
        await onReset();
        return null;
      }
      if (hasCode(error, 'invalid_password')) {
        return createValidationError({fields: {password: passwordProblemMessage(error.reason)}});
      }
      // It expired, or the Instance Administrator replaced it, since the page opened
      if (hasCode(error, 'link_no_longer_works')) {
        queryClient.setQueryData(passwordResetLinkQuery(token).queryKey, {username: null});
        return null;
      }
      return createValidationError(t($ => $.core.errors.somethingWentWrong));
    },
  });
}
