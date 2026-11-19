import {useMutation} from '@tanstack/react-query';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {savePreferencesMutation} from '@watchclub/core/accounts/preferences';
import {useInstanceName} from '@watchclub/core/instance';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner-native';
import {ChoiceScreen} from '@/components/layouts/choice-screen';

/** The User's Locale, which the app switches to once picked. */
export default function Language() {
  const {t, i18n} = useTranslation('core');
  const localeNames = useLocaleNames();
  const instanceName = useInstanceName();
  const user = useCurrentUser();
  const save = useMutation(savePreferencesMutation);

  return (
    <ChoiceScreen
      label={t($ => $.core.settings.language)}
      options={LOCALES.map(locale => ({value: locale, label: localeNames[locale]}))}
      value={user.preferences.locale}
      save={async locale => {
        await save.mutateAsync({user: user.id, changes: {locale}});
        // In the new Locale, as the app now is, rather than in this render's
        const tNew = i18n.getFixedT(locale, 'core');
        toast.success(tNew($ => $.core.settings.languageSaved));
      }}
      isSaving={save.isPending}
      hasFailed={save.isError}
      hint={t($ => $.core.settings.preferencesDescription, {name: instanceName})}
    />
  );
}
