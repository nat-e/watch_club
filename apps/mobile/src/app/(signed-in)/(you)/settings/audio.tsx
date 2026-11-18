import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {
  savePreferencesMutation,
  useTrackLanguageOptions,
} from '@watchclub/core/accounts/preferences';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner-native';
import {ChoiceScreen} from '@/components/layouts/choice-screen';

/** The User's Preferred Audio Language. */
export default function Audio() {
  const {t} = useTranslation('core');
  const options = useTrackLanguageOptions();
  const user = useCurrentUser();
  const save = useMutation(savePreferencesMutation);

  return (
    <ChoiceScreen
      label={t($ => $.core.settings.audio)}
      options={options.audio}
      value={user.preferences.audio_language}
      save={async language => {
        // biome-ignore lint/style/useNamingConvention: the API's field
        await save.mutateAsync({user: user.id, changes: {audio_language: language}});
        toast.success(t($ => $.core.settings.audioAndSubtitlesSaved));
      }}
      isSaving={save.isPending}
      hasFailed={save.isError}
    />
  );
}
