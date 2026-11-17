import {FieldGroup} from '@expo/ui';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useSavePreferences} from '@watchclub/core/accounts/preferences';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {choiceRows} from '@/components/forms/choice-rows';
import {Feedback} from '@/components/forms/feedback';
import {ListScreen} from '@/components/list-screen';

/** Settings, where Users choose their User Preferences. Picking a language saves it. */
export default function Settings() {
  const {t} = useTranslation('core');
  const localeNames = useLocaleNames();
  const user = useCurrentUser();
  const save = useSavePreferences();
  const language = t($ => $.core.settings.language);

  return (
    <ListScreen>
      <FieldGroup.Section title={language}>
        {choiceRows({
          label: language,
          options: LOCALES.map(locale => ({value: locale, label: localeNames[locale]})),
          value: user.locale,
          disabled: save.isPending,
          onChange: locale => save.mutateAsync({locale}),
        })}
        <FieldGroup.SectionFooter>
          <Feedback
            error={save.isError ? t($ => $.core.errors.somethingWentWrong) : undefined}
            hint={t($ => $.core.settings.preferencesDescription)}
          />
        </FieldGroup.SectionFooter>
      </FieldGroup.Section>
    </ListScreen>
  );
}
