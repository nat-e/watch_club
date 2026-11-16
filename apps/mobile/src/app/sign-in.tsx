import {useMutation} from '@tanstack/react-query';
import {loginTokenMutation} from '@watchclub/api';
import {useSignInForm} from '@watchclub/core/accounts/sign-in';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {Text} from 'react-native';
import {Button} from '@/components/button';
import {Screen} from '@/components/screen';
import {TextField} from '@/components/text-field';
import {useSession} from '@/session';

/** Where the User signs in to their WatchClub with their username and password. */
export default function SignIn() {
  const {t} = useTranslation(['mobile', 'core']);
  const session = useSession();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const signIn = useMutation({
    ...loginTokenMutation(),
    onSuccess: session.signIn,
  });
  const form = useSignInForm(signIn);

  function submit() {
    form.submit(username, password);
  }

  return (
    <Screen>
      <Text accessibilityRole="header" className="text-3xl font-semibold text-foreground">
        {t($ => $.core.signIn.title)}
      </Text>
      <TextField
        label={t($ => $.core.user.username)}
        error={form.usernameError}
        value={username}
        onChangeText={setUsername}
        autoCapitalize="none"
        autoCorrect={false}
        autoComplete="username"
        textContentType="username"
        autoFocus
        returnKeyType="next"
      />
      <TextField
        label={t($ => $.core.user.password)}
        error={form.passwordError}
        value={password}
        onChangeText={setPassword}
        onSubmitEditing={submit}
        secureTextEntry
        autoComplete="current-password"
        textContentType="password"
        returnKeyType="go"
      />
      {form.failed && (
        <Text accessibilityLiveRegion="polite" className="text-destructive">
          {t($ => $.core.errors.somethingWentWrong)}
        </Text>
      )}
      <Button disabled={signIn.isPending} onPress={submit}>
        {t($ => $.core.signIn.submit)}
      </Button>
      <Text className="text-sm text-muted-foreground">{t($ => $.core.signIn.forgotPassword)}</Text>
      <Button variant="outline" onPress={session.disconnect}>
        {t($ => $.mobile.signIn.useAnotherAddress)}
      </Button>
    </Screen>
  );
}
