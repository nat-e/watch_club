import {useMutation} from '@tanstack/react-query';
import {useUser} from '@watchclub/core/accounts/session';
import {useRouter} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {Text, View} from 'react-native';
import {Button} from '@/components/button';
import {Screen} from '@/components/screen';
import {useSession} from '@/session';

/** Home, where signed-in Users land: who they are, their settings, and signing out. */
export default function Home() {
  const {t} = useTranslation('core');
  const user = useUser();
  const router = useRouter();
  const signOut = useMutation({mutationFn: useSession().signOut});

  return (
    <Screen>
      <View className="gap-1">
        <Text className="text-2xl font-semibold text-foreground">{user.username}</Text>
        {user.is_instance_administrator && (
          <Text className="text-muted-foreground">{t($ => $.core.user.instanceAdministrator)}</Text>
        )}
      </View>
      <Button variant="outline" onPress={() => router.navigate('/settings')}>
        {t($ => $.core.settings.title)}
      </Button>
      <Button variant="outline" disabled={signOut.isPending} onPress={() => signOut.mutate()}>
        {t($ => $.core.user.signOut)}
      </Button>
    </Screen>
  );
}
