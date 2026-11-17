import {FieldGroup, Text} from '@expo/ui';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useSavePreferences} from '@watchclub/core/accounts/preferences';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {useCSSVariable} from 'uniwind';
import {choiceRows} from '@/components/choice-rows';
import {FormScreen} from '@/components/form-screen';

/** Settings, where Users choose their User Preferences. Picking a language saves it. */
export default function Settings() {
  const {t} = useTranslation('core');
  const localeNames = useLocaleNames();
  const user = useCurrentUser();
  const save = useSavePreferences();
  const language = t($ => $.core.settings.language);
  const [mutedForeground, destructive] = useCSSVariable([
    '--color-muted-foreground',
    '--color-destructive',
  ]).map(value => String(value));

  return (
    <FormScreen>
      <FieldGroup.Section title={language}>
        {choiceRows({
          label: language,
          options: LOCALES.map(locale => ({value: locale, label: localeNames[locale]})),
          value: user.locale,
          disabled: save.isPending,
          onChange: locale => save.mutateAsync({locale}),
        })}
        <FieldGroup.SectionFooter>
          {save.isError ? (
            <Text textStyle={{color: destructive}}>{t($ => $.core.errors.somethingWentWrong)}</Text>
          ) : (
            <Text textStyle={{color: mutedForeground}}>
              {t($ => $.core.settings.preferencesDescription)}
            </Text>
          )}
        </FieldGroup.SectionFooter>
      </FieldGroup.Section>
    </FormScreen>
  );
}
