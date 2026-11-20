import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {
  savePreferencesMutation,
  useTrackLanguageOptions,
} from '@watchclub/core/accounts/preferences';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner-native';
import {ChoiceScreen} from '@/components/layouts/choice-screen';

/** The User's Preferred Subtitle Language, or no subtitles. */
export default function Subtitles() {
  const {t} = useTranslation('core');
  const options = useTrackLanguageOptions();
  const user = useCurrentUser();
  const save = useMutation(savePreferencesMutation);

  return (
    <ChoiceScreen
      label={t($ => $.core.settings.subtitles)}
      options={options.subtitles}
      value={user.preferences.subtitle_language}
      save={async language => {
        // biome-ignore lint/style/useNamingConvention: the API's field
        await save.mutateAsync({userId: user.id, changes: {subtitle_language: language}});
        toast.success(t($ => $.core.settings.audioAndSubtitlesSaved));
      }}
      isSaving={save.isPending}
      hasFailed={save.isError}
    />
  );
}
