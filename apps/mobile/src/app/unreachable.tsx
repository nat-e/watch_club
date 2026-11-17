import {useMutation} from '@tanstack/react-query';
import {useTranslation} from 'react-i18next';
import {StatusScreen} from '@/components/status-screen';
import {useRetrySession, useSessionStore} from '@/session';

/**
 * The screen saying the app can't reach the User's WatchClub, as when the device is offline, with a
 * way to try again, or to sign out and sign in elsewhere.
 */
export default function Unreachable() {
  const {t} = useTranslation(['mobile', 'core']);
  const {retry, isRetrying} = useRetrySession();
  const sessionStore = useSessionStore();
  const signOut = useMutation({mutationFn: () => sessionStore.signOut()});

  return (
    <StatusScreen
      title={t($ => $.mobile.unreachable.title)}
      description={t($ => $.mobile.unreachable.description)}
      actions={[
        {label: t($ => $.mobile.unreachable.tryAgain), onPress: retry, disabled: isRetrying},
        {
          label: t($ => $.core.user.signOut),
          onPress: () => {
            signOut.mutate();
          },
          disabled: signOut.isPending,
        },
      ]}
    />
  );
}
