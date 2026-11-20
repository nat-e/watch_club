import {FieldGroup} from '@expo/ui';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {labelOf, useTrackLanguageOptions} from '@watchclub/core/accounts/preferences';
import {useLocaleNames} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {ListScreen} from '@/components/layouts/list-screen';
import {linkRow} from '@/components/lists/link-row';
import {Feedback} from '@/components/text';

/**
 * Settings, where Users choose their User Preferences: each row opens the screen to change it. Then
 * About, with TMDB's notice.
 */
export default function Settings() {
  const {t} = useTranslation(['core', 'mobile']);
  const localeNames = useLocaleNames();
  const options = useTrackLanguageOptions();
  const {preferences} = useCurrentUser();
  const languagesWithoutSubtitles = options.languages
    .filter(option => preferences.languages_without_subtitles.includes(option.value))
    .map(option => option.label);

  return (
    <ListScreen>
      <FieldGroup.Section>
        {linkRow({
          label: t($ => $.core.settings.language),
          value: localeNames[preferences.locale],
          href: '/settings/language',
        })}
      </FieldGroup.Section>
      <FieldGroup.Section title={t($ => $.core.settings.audioAndSubtitles)}>
        {linkRow({
          label: t($ => $.core.settings.audio),
          value: labelOf(options.audio, preferences.audio_language),
          href: '/settings/audio',
        })}
        {linkRow({
          label: t($ => $.core.settings.subtitles),
          value: labelOf(options.subtitles, preferences.subtitle_language),
          href: '/settings/subtitles',
        })}
        {linkRow({
          label: t($ => $.core.settings.languagesWithoutSubtitles),
          value:
            languagesWithoutSubtitles.length > 0
              ? languagesWithoutSubtitles.join(', ')
              : t($ => $.mobile.settings.noLanguages),
          href: '/settings/languages-without-subtitles',
        })}
        <FieldGroup.SectionFooter>
          <Feedback hint={t($ => $.core.settings.audioAndSubtitlesDescription)} />
        </FieldGroup.SectionFooter>
      </FieldGroup.Section>
      <FieldGroup.Section>
        {linkRow({label: t($ => $.core.settings.about), href: '/settings/about'})}
      </FieldGroup.Section>
    </ListScreen>
  );
}
