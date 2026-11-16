import {useSignInFormOptions} from '@watchclub/core/accounts/sign-in';
import {type ComponentRef, useRef} from 'react';
import {useTranslation} from 'react-i18next';
import {Text, type TextInput} from 'react-native';
import {Button} from '@/components/button';
import {useAppForm} from '@/components/form';
import {Screen} from '@/components/screen';
import {checkInstance, type InstanceProblem} from '@/instance-url';
import {useSession, useSessionStore} from '@/session';

/** The form that signs the User in to their WatchClub: its address, username and password. */
export default function SignIn() {
  const {t} = useTranslation(['mobile', 'core']);
  const {session} = useSession();
  const sessionStore = useSessionStore();
  // The keyboard's next key moves from one field to the next
  const usernameInput = useRef<ComponentRef<typeof TextInput>>(null);
  const passwordInput = useRef<ComponentRef<typeof TextInput>>(null);
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

  function submit() {
    void instanceForm.handleSubmit();
  }

  return (
    <Screen>
      <Text accessibilityRole="header" className="text-3xl font-semibold text-foreground">
        {t($ => $.core.signIn.title)}
      </Text>
      {session.instanceUrl === null && (
        <Text className="text-base text-muted-foreground">
          {t($ => $.mobile.signIn.description)}
        </Text>
      )}
      <instanceForm.Field name="address">
        {field => (
          <field.TextField
            label={t($ => $.mobile.signIn.address)}
            placeholder={t($ => $.mobile.signIn.addressPlaceholder)}
            autoCapitalize="none"
            autoCorrect={false}
            autoFocus={session.instanceUrl === null}
            inputMode="url"
            returnKeyType="next"
            submitBehavior="submit"
            onSubmitEditing={() => {
              usernameInput.current?.focus();
            }}
          />
        )}
      </instanceForm.Field>
      <signInForm.AppForm>
        <signInForm.Field name="username">
          {field => (
            <field.TextField
              ref={usernameInput}
              label={t($ => $.core.user.username)}
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="username"
              textContentType="username"
              autoFocus={session.instanceUrl !== null}
              returnKeyType="next"
              submitBehavior="submit"
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
              onSubmitEditing={submit}
              secureTextEntry
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="current-password"
              textContentType="password"
              returnKeyType="go"
            />
          )}
        </signInForm.Field>
        <signInForm.FormError />
      </signInForm.AppForm>
      <instanceForm.Subscribe selector={state => state.isSubmitting}>
        {isSubmitting => (
          <Button disabled={isSubmitting} onPress={submit}>
            {t($ => $.core.signIn.submit)}
          </Button>
        )}
      </instanceForm.Subscribe>
      <Text className="text-sm text-muted-foreground">{t($ => $.core.signIn.forgotPassword)}</Text>
    </Screen>
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
