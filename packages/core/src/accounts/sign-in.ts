/**
 * The sign-in form's rules, which both apps follow: which fields it asks for, and which message
 * shows under each one.
 */
import {formOptions} from '@tanstack/react-form';
import {type Credentials, hasCode} from '@watchclub/api';
import {useTranslation} from 'react-i18next';

/**
 * Returns the options of the sign-in form, for each app's `useAppForm`: its fields, and the
 * messages for an empty field and for the API's errors. `signIn` sends the credentials the app's
 * way, for a session cookie on the web or a session token on mobile, and throws the API's error.
 */
export function useSignInFormOptions(signIn: (credentials: Credentials) => Promise<void>) {
  const {t} = useTranslation('core');
  return formOptions({
    defaultValues: {username: '', password: ''},
    validators: [
      {
        // On submit only: the fields start empty
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          if (value.username.trim() === '') {
            errors.fields.username = t($ => $.core.signIn.enterUsername);
          }
          if (value.password === '') {
            errors.fields.password = t($ => $.core.signIn.enterPassword);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      try {
        await signIn({username: value.username.trim(), password: value.password});
        return null;
      } catch (error) {
        return hasCode(error, 'wrong_credentials')
          ? createValidationError({fields: {password: t($ => $.core.signIn.wrongCredentials)}})
          : createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
    },
  });
}
