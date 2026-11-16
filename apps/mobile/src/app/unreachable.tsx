import {useMutation} from '@tanstack/react-query';
import {useTranslation} from 'react-i18next';
import {Text} from 'react-native';
import {Button} from '@/components/button';
import {Screen} from '@/components/screen';
import {useRetrySession, useSessionStore} from '@/session';

/**
 * Shows that the app can't reach the User's WatchClub, as when the device is offline, and lets
 * them try again, or sign out to sign in elsewhere.
 */
export default function Unreachable() {
  const {t} = useTranslation(['mobile', 'core']);
  const {retry, isRetrying} = useRetrySession();
  const sessionStore = useSessionStore();
  const signOut = useMutation({mutationFn: () => sessionStore.signOut()});

  return (
    <Screen>
      <Text accessibilityRole="header" className="text-3xl font-semibold text-foreground">
        {t($ => $.mobile.unreachable.title)}
      </Text>
      <Text className="text-base text-muted-foreground">
        {t($ => $.mobile.unreachable.description)}
      </Text>
      <Button disabled={isRetrying} onPress={retry}>
        {t($ => $.mobile.unreachable.tryAgain)}
      </Button>
      <Button
        variant="outline"
        disabled={signOut.isPending}
        onPress={() => {
          signOut.mutate();
        }}
      >
        {t($ => $.core.user.signOut)}
      </Button>
    </Screen>
  );
}
