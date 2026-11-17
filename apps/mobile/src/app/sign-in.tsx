import {FieldGroup, ListItem, Text, type TextInputRef} from '@expo/ui';
import {useSelector} from '@tanstack/react-form';
import {useSignInFormOptions} from '@watchclub/core/accounts/sign-in';
import {Stack} from 'expo-router';
import {useRef} from 'react';
import {useTranslation} from 'react-i18next';
import {useCSSVariable} from 'uniwind';
import {useAppForm} from '@/components/form';
import {FormScreen} from '@/components/form-screen';
import {checkInstance, type InstanceProblem} from '@/instance-url';
import {useSession, useSessionStore} from '@/session';

/**
 * The form that signs the User in to their WatchClub: its address, username and password, each in
 * its own section with its error under it.
 */
export default function SignIn() {
  const {t} = useTranslation(['mobile', 'core']);
  const {session} = useSession();
  const sessionStore = useSessionStore();
  // The keyboard's next key moves from one field to the next
  const usernameInput = useRef<TextInputRef>(null);
  const passwordInput = useRef<TextInputRef>(null);
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
  const isSubmitting = useSelector(instanceForm.atom, state => state.isSubmitting);
  const [primary, mutedForeground] = useCSSVariable([
    '--color-primary',
    '--color-muted-foreground',
  ]).map(value => String(value));

  function submit() {
    void instanceForm.handleSubmit();
  }

  const address = t($ => $.mobile.signIn.address);
  const username = t($ => $.core.user.username);
  const password = t($ => $.core.user.password);

  return (
    <>
      <Stack.Screen options={{headerShown: true, title: t($ => $.core.signIn.title)}} />
      <FormScreen>
        <FieldGroup.Section title={address}>
          <instanceForm.Field name="address">
            {field => (
              <field.TextInput
                accessibilityLabel={address}
                placeholder={t($ => $.mobile.signIn.addressPlaceholder)}
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="url"
                autoFocus={session.instanceUrl === null}
                inputMode="url"
                returnKeyType="next"
                onSubmitEditing={() => {
                  usernameInput.current?.focus();
                }}
              />
            )}
          </instanceForm.Field>
          <FieldGroup.SectionFooter>
            <instanceForm.Field name="address">
              {field => (
                <field.Message
                  hint={
                    session.instanceUrl === null ? t($ => $.mobile.signIn.description) : undefined
                  }
                />
              )}
            </instanceForm.Field>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>
        <FieldGroup.Section title={username}>
          <signInForm.Field name="username">
            {field => (
              <field.TextInput
                ref={usernameInput}
                accessibilityLabel={username}
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="username"
                autoFocus={session.instanceUrl !== null}
                returnKeyType="next"
                onSubmitEditing={() => {
                  passwordInput.current?.focus();
                }}
              />
            )}
          </signInForm.Field>
          <FieldGroup.SectionFooter>
            <signInForm.Field name="username">{field => <field.Message />}</signInForm.Field>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>
        <FieldGroup.Section title={password}>
          <signInForm.Field name="password">
            {field => (
              <field.TextInput
                ref={passwordInput}
                accessibilityLabel={password}
                secureTextEntry
                autoCapitalize="none"
                autoCorrect={false}
                autoComplete="current-password"
                returnKeyType="go"
                onSubmitEditing={submit}
              />
            )}
          </signInForm.Field>
          <FieldGroup.SectionFooter>
            <signInForm.Field name="password">{field => <field.Message />}</signInForm.Field>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>
        <FieldGroup.Section>
          <ListItem onPress={isSubmitting ? undefined : submit}>
            <Text textStyle={{color: isSubmitting ? mutedForeground : primary}}>
              {t($ => $.core.signIn.submit)}
            </Text>
          </ListItem>
          <FieldGroup.SectionFooter>
            <signInForm.AppForm>
              <signInForm.FormMessage hint={t($ => $.core.signIn.forgotPassword)} />
            </signInForm.AppForm>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>
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
