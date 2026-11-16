import {useMutation} from '@tanstack/react-query';
import {useSignInFormOptions} from '@watchclub/core/accounts/sign-in';
import {type ComponentRef, useRef} from 'react';
import {useTranslation} from 'react-i18next';
import {Text, type TextInput} from 'react-native';
import {Button} from '@/components/button';
import {useAppForm} from '@/components/form';
import {Screen} from '@/components/screen';
import {checkInstance, type InstanceProblem} from '@/instance-url';
import {useSession, useSessionStore} from '@/session';

/** Where the User signs in to their WatchClub with its address, their username and password. */
export default function SignIn() {
  const {t} = useTranslation(['mobile', 'core']);
  const {session} = useSession();
  const sessionStore = useSessionStore();
  const {form: instanceForm, checkedUrl} = useInstanceForm(session.instanceUrl);
  // The keyboard's next key moves from one field to the next
  const usernameInput = useRef<ComponentRef<typeof TextInput>>(null);
  const passwordInput = useRef<ComponentRef<typeof TextInput>>(null);
  // Where the credentials go: the URL the last submit found a WatchClub at
  const destination = useRef<string | null>(null);
  const signInForm = useAppForm(
    useSignInFormOptions(credentials => {
      if (destination.current === null) {
        throw new Error('only an address a check found a WatchClub at signs in');
      }
      return sessionStore.signIn(destination.current, credentials);
    }),
  );
  const submit = useMutation({
    mutationFn: async () => {
      // The address first, so the credentials only go where a check found a WatchClub
      await instanceForm.handleSubmit();
      destination.current = checkedUrl();
      if (destination.current !== null) {
        await signInForm.handleSubmit();
      }
    },
  });

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
              onSubmitEditing={() => {
                submit.mutate();
              }}
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
      <Button
        disabled={submit.isPending}
        onPress={() => {
          submit.mutate();
        }}
      >
        {t($ => $.core.signIn.submit)}
      </Button>
      <Text className="text-sm text-muted-foreground">{t($ => $.core.signIn.forgotPassword)}</Text>
    </Screen>
  );
}

/**
 * Returns the form with the Instance's address, which starts with the last Instance's, and checks
 * that a WatchClub that's set up answers there once the User leaves the field.
 */
function useInstanceForm(lastInstanceUrl: string | null) {
  const {t} = useTranslation('mobile');
  const messages: Record<InstanceProblem, string> = {
    invalidAddress: t($ => $.mobile.signIn.enterAddress),
    unreachable: t($ => $.mobile.signIn.unreachable),
    needsSetup: t($ => $.mobile.signIn.needsSetup),
  };
  // The address a check last found a WatchClub at, and its URL. The form's errors alone don't
  // tell: a check the User interrupts, by changing the address, leaves none
  const found = useRef<{address: string; url: string} | null>(null);
  const form = useAppForm({
    defaultValues: {address: lastInstanceUrl ?? ''},
    validators: [
      {
        triggers: ['blur'],
        run: async ({value, createErrorMap}) => {
          const errors = createErrorMap();
          const check = await checkInstance(value.address);
          if ('url' in check) {
            found.current = {address: value.address, url: check.url};
          } else {
            found.current = null;
            errors.fields.address = messages[check.problem];
          }
          return errors;
        },
      },
    ],
  });

  /** Returns the URL of the address in the field, if a check found a WatchClub there. */
  function checkedUrl(): string | null {
    return found.current?.address === form.state.values.address ? found.current.url : null;
  }

  return {form, checkedUrl};
}
