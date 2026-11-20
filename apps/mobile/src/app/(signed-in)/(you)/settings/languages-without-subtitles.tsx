import {FieldGroup} from '@expo/ui';
import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {
  savePreferencesMutation,
  useTrackLanguageOptions,
} from '@watchclub/core/accounts/preferences';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner-native';
import {EditScreen} from '@/components/layouts/edit-screen';
import {checkRows} from '@/components/lists/check-rows';
import {Feedback} from '@/components/text';

/** The User's Languages Without Subtitles, which they pick, then save together. */
export default function LanguagesWithoutSubtitles() {
  const {t} = useTranslation('core');
  const options = useTrackLanguageOptions();
  const user = useCurrentUser();
  const save = useMutation(savePreferencesMutation);
  const [languages, setLanguages] = useState(user.preferences.languages_without_subtitles);

  return (
    <EditScreen
      save={async () => {
        await save.mutateAsync({
          userId: user.id,
          // biome-ignore lint/style/useNamingConvention: the API's field
          changes: {languages_without_subtitles: languages},
        });
        toast.success(t($ => $.core.settings.audioAndSubtitlesSaved));
      }}
      isSaving={save.isPending}
    >
      <FieldGroup.Section>
        {checkRows({
          options: options.languages,
          value: languages,
          disabled: save.isPending,
          onChange: setLanguages,
        })}
        <FieldGroup.SectionFooter>
          <Feedback
            error={save.isError ? t($ => $.core.errors.somethingWentWrong) : undefined}
            hint={t($ => $.core.settings.languagesWithoutSubtitlesDescription)}
          />
        </FieldGroup.SectionFooter>
      </FieldGroup.Section>
    </EditScreen>
  );
}
