/**
 * The sign-in form's rules, which both apps follow: which fields it asks for, and which message
 * shows under each one.
 */
import {
  type Credentials,
  type LoginError,
  type LoginTokenError,
  UnexpectedError,
} from '@watchclub/api';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';

/** The request that signs in: for a session cookie on the web, or a session token on mobile. */
interface SignInRequest {
  error: LoginError | LoginTokenError | UnexpectedError | null;
  mutate(variables: {body: Credentials}): void;
}

/** The messages a sign-in form shows, and how it signs in. */
interface SignInForm {
  /** Signs in, or asks for the username or password if one is empty. */
  submit(username: string, password: string): void;
  /** The message under the username field, if any */
  usernameError?: string;
  /** The message under the password field, if any, such as when it's wrong */
  passwordError?: string;
  /** Whether signing in went wrong for another reason than the username or password */
  failed: boolean;
}

/** Returns the state of a sign-in form that signs in with `request`. */
export function useSignInForm(request: SignInRequest): SignInForm {
  const {t} = useTranslation('core');
  const [missing, setMissing] = useState({username: false, password: false});
  const wrongCredentials = request.error !== null && isWrongCredentials(request.error);

  function submit(username: string, password: string) {
    const trimmedUsername = username.trim();
    const missing = {username: trimmedUsername === '', password: password === ''};
    setMissing(missing);
    if (!missing.username && !missing.password) {
      request.mutate({body: {username: trimmedUsername, password}});
    }
  }

  return {
    submit,
    usernameError: missing.username ? t($ => $.core.signIn.enterUsername) : undefined,
    passwordError: missing.password
      ? t($ => $.core.signIn.enterPassword)
      : wrongCredentials
        ? t($ => $.core.signIn.wrongCredentials)
        : undefined,
    failed: request.error !== null && !wrongCredentials,
  };
}

/** Returns whether signing in failed because of the username or password, rather than going wrong. */
function isWrongCredentials(error: LoginError | LoginTokenError | UnexpectedError): boolean {
  if (error instanceof UnexpectedError) {
    return false;
  }
  switch (error.code) {
    case 'wrong_credentials':
      return true;
    case 'invalid_request':
    case 'internal_error':
      return false;
  }
}
