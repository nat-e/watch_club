/**
 * Passwords: the rules of a new password, which both apps show, the form that changes the User's
 * password in Settings, and the Password Reset Links that let a User who forgot theirs choose a new
 * one.
 */
import {formOptions} from '@tanstack/react-form';
import {queryOptions} from '@tanstack/react-query';
import {
  changePassword,
  checkPasswordResetLinkOptions,
  hasCode,
  type PasswordProblem,
} from '@watchclub/api';
import {useTranslation} from 'react-i18next';

/** The fewest characters a password has, which its hint says */
export const PASSWORD_MIN_LENGTH = 8;

/** Returns the function that says, in the User's language, which rule a new password breaks. */
export function usePasswordProblemMessage(): (problem: PasswordProblem) => string {
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

/**
 * Returns the options of the form that changes the User's password, for each app's `useAppForm`:
 * their current password, and a new one typed twice. The form empties once the password changed,
 * and the API signed the User out on their other devices, then `onChanged` runs, such as to say so.
 */
export function useChangePasswordFormOptions(onChanged: () => void) {
  const {t} = useTranslation('core');
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
      const {error} = await changePassword({
        // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
        body: {current_password: value.currentPassword, new_password: value.newPassword},
      });
      if (error === undefined) {
        formApi.reset();
        onChanged();
        return null;
      }
      if (hasCode(error, 'wrong_password')) {
        return createValidationError({
          fields: {currentPassword: t($ => $.core.password.wrongCurrentPassword)},
        });
      }
      if (hasCode(error, 'invalid_password')) {
        return createValidationError({
          fields: {newPassword: passwordProblemMessage(error.reason)},
        });
      }
      return createValidationError(t($ => $.core.errors.somethingWentWrong));
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
