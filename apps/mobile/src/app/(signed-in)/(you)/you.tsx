import {FieldGroup, Icon, ListItem, Text} from '@expo/ui';
import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useRouter} from 'expo-router';
import {useTranslation} from 'react-i18next';
import {Platform} from 'react-native';
import {useCSSVariable} from 'uniwind';
import {ListScreen} from '@/components/list-screen';
import {useSessionStore} from '@/session';

/** You: who the User is, the pages that have no tab, and signing out. */
export default function You() {
  const {t} = useTranslation('core');
  const user = useCurrentUser();
  const router = useRouter();
  const sessionStore = useSessionStore();
  const signOut = useMutation({mutationFn: () => sessionStore.signOut()});
  const [mutedForeground, destructive] = useCSSVariable([
    '--color-muted-foreground',
    '--color-destructive',
  ]).map(value => String(value));
  // iOS marks the rows that open a page; Android's lists don't
  const chevron =
    Platform.OS === 'ios' ? <Icon name="chevron.right" size={14} color={mutedForeground} /> : null;

  return (
    <ListScreen>
      <FieldGroup.Section>
        <ListItem
          supportingText={
            user.is_instance_administrator ? t($ => $.core.user.instanceAdministrator) : undefined
          }
        >
          {user.username}
        </ListItem>
      </FieldGroup.Section>
      <FieldGroup.Section>
        <ListItem
          trailing={chevron}
          onPress={() => {
            router.navigate('/my-requests');
          }}
        >
          {t($ => $.core.myRequests.navigationLabel)}
        </ListItem>
        <ListItem
          trailing={chevron}
          onPress={() => {
            router.navigate('/settings');
          }}
        >
          {t($ => $.core.settings.title)}
        </ListItem>
      </FieldGroup.Section>
      <FieldGroup.Section>
        <ListItem
          onPress={
            signOut.isPending
              ? undefined
              : () => {
                  signOut.mutate();
                }
          }
        >
          <Text textStyle={{color: destructive}}>{t($ => $.core.user.signOut)}</Text>
        </ListItem>
      </FieldGroup.Section>
    </ListScreen>
  );
}
