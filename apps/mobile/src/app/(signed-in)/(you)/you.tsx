import {FieldGroup, ListItem, Text} from '@expo/ui';
import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useTranslation} from 'react-i18next';
import {useCSSVariable} from 'uniwind';
import {ListScreen} from '@/components/layouts/list-screen';
import {linkRow} from '@/components/lists/link-row';
import {useSessionStore} from '@/session';

/** You: who the User is, the pages that have no tab, and signing out. */
export default function You() {
  const {t} = useTranslation('core');
  const user = useCurrentUser();
  const sessionStore = useSessionStore();
  const signOut = useMutation({mutationFn: () => sessionStore.signOut()});
  const destructive = useCSSVariable('--color-destructive');

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
        {linkRow({label: t($ => $.core.myRequests.navigationLabel), href: '/my-requests'})}
        {linkRow({label: t($ => $.core.settings.title), href: '/settings'})}
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
          <Text textStyle={{color: String(destructive)}}>{t($ => $.core.user.signOut)}</Text>
        </ListItem>
      </FieldGroup.Section>
    </ListScreen>
  );
}
