import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useRouter} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {Text, View} from 'react-native';
import {Button} from '@/components/button';
import {Screen} from '@/components/screen';
import {useSessionStore} from '@/session';

/** You: who the User is, the pages that have no tab, and signing out. */
export default function You() {
  const {t} = useTranslation('core');
  const user = useCurrentUser();
  const router = useRouter();
  const sessionStore = useSessionStore();
  const signOut = useMutation({mutationFn: () => sessionStore.signOut()});

  return (
    <Screen>
      <View className="gap-1">
        <Text className="text-2xl font-semibold text-foreground">{user.username}</Text>
        {user.is_instance_administrator && (
          <Text className="text-muted-foreground">{t($ => $.core.user.instanceAdministrator)}</Text>
        )}
      </View>
      <Button
        variant="outline"
        onPress={() => {
          router.navigate('/my-requests');
        }}
      >
        {t($ => $.core.myRequests.navigationLabel)}
      </Button>
      <Button
        variant="outline"
        onPress={() => {
          router.navigate('/settings');
        }}
      >
        {t($ => $.core.settings.title)}
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
