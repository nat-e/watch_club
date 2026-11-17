import {useSignInFormOptions} from '@watchclub/core/accounts/sign-in';
import {Stack} from 'expo-router';
import {useRef} from 'react';
import {useTranslation} from 'react-i18next';
import {useAppForm} from '@/components/forms/form';
import {FormScreen} from '@/components/forms/form-screen';
import type {FocusableField} from '@/components/forms/text-field';
import {checkInstance, type InstanceProblem} from '@/instance-url';
import {useSession, useSessionStore} from '@/session';

/** The form that signs the User in to their WatchClub: its address, username and password. */
export default function SignIn() {
  const {t} = useTranslation(['mobile', 'core']);
  const {session} = useSession();
  const sessionStore = useSessionStore();
  // The keyboard's next key moves from one field to the next
  const usernameInput = useRef<FocusableField>(null);
  const passwordInput = useRef<FocusableField>(null);
  // The URL the credentials go to, which the address form's submission found a WatchClub at
  const destination = useRef<string | null>(null);
  const signInForm = useAppForm(
    useSignInFormOptions(credentials => {
      if (destination.current === null) {
        throw new Error('the credentials only go where the address form found a WatchClub');
      }
      return sessionStore.signIn(destination.current, credentials);
    }),
  );
  // The address first, so the credentials only go where a check found a WatchClub
  const instanceForm = useInstanceForm(session.instanceUrl, async instanceUrl => {
    destination.current = instanceUrl;
    await signInForm.handleSubmit();
  });

  return (
    <>
      <Stack.Screen options={{headerShown: true, title: t($ => $.core.signIn.title)}} />
      <FormScreen
        description={session.instanceUrl === null ? t($ => $.mobile.signIn.description) : undefined}
      >
        <instanceForm.Field name="address">
          {field => (
            <field.TextField
              label={t($ => $.mobile.signIn.address)}
              purpose="url"
              placeholder={t($ => $.mobile.signIn.addressPlaceholder)}
              autoFocus={session.instanceUrl === null}
              returnKeyType="next"
              onSubmitEditing={() => {
                usernameInput.current?.focus();
              }}
            />
          )}
        </instanceForm.Field>
        <signInForm.Field name="username">
          {field => (
            <field.TextField
              ref={usernameInput}
              label={t($ => $.core.user.username)}
              purpose="username"
              autoFocus={session.instanceUrl !== null}
              returnKeyType="next"
              onSubmitEditing={() => {
                passwordInput.current?.focus();
              }}
            />
          )}
        </signInForm.Field>
        <signInForm.Field name="password">
          {field => (
            <field.TextField
              ref={passwordInput}
              label={t($ => $.core.user.password)}
              purpose="current-password"
              returnKeyType="go"
              onSubmitEditing={() => {
                void instanceForm.handleSubmit();
              }}
            />
          )}
        </signInForm.Field>
        <instanceForm.AppForm>
          <instanceForm.SubmitButton>{t($ => $.core.signIn.submit)}</instanceForm.SubmitButton>
        </instanceForm.AppForm>
        <signInForm.AppForm>
          <signInForm.FormFeedback hint={t($ => $.core.signIn.forgotPassword)} />
        </signInForm.AppForm>
      </FormScreen>
    </>
  );
}

/**
 * Returns the form with the Instance's address, which starts with the last Instance's. It checks
 * that a WatchClub that's set up answers there once the User leaves the field, and on submit, which
 * then gives the Instance's URL to `signIn`.
 */
function useInstanceForm(
  lastInstanceUrl: string | null,
  signIn: (instanceUrl: string) => Promise<void>,
) {
  const {t} = useTranslation('mobile');
  const messages: Record<InstanceProblem, string> = {
    invalidAddress: t($ => $.mobile.signIn.enterAddress),
    unreachable: t($ => $.mobile.signIn.unreachable),
    needsSetup: t($ => $.mobile.signIn.needsSetup),
  };
  return useAppForm({
    defaultValues: {address: lastInstanceUrl ?? ''},
    validators: [
      {
        triggers: ['blur'],
        run: async ({value, createErrorMap, createOutput}) => {
          const check = await checkInstance(value.address);
          if ('url' in check) {
            return createOutput(check.url);
          }
          const errors = createErrorMap();
          errors.fields.address = messages[check.problem];
          return errors;
        },
      },
    ],
    // The URL from this submission's check, which an earlier check can't replace
    onSubmit: ({validatorOutputs}) => {
      const [instanceUrl] = validatorOutputs;
      if (instanceUrl === undefined) {
        throw new Error('the address check runs on each submit, and gives the URL once it passes');
      }
      return signIn(instanceUrl);
    },
  });
}
