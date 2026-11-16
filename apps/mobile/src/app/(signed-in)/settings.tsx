import {useSavePreferences} from '@watchclub/core/accounts/preferences';
import {useUser} from '@watchclub/core/accounts/session';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {useTranslation} from 'react-i18next';
import {Pressable, Text, View} from 'react-native';
import {Screen} from '@/components/screen';

/** Settings, where Users choose their User Preferences. Picking a language saves it. */
export default function Settings() {
  const {t} = useTranslation('core');
  const localeNames = useLocaleNames();
  const user = useUser();
  const save = useSavePreferences();

  return (
    <Screen>
      <Text className="text-base text-muted-foreground">{t($ => $.core.settings.description)}</Text>
      <View className="gap-1">
        <Text accessibilityRole="header" className="text-lg font-semibold text-foreground">
          {t($ => $.core.settings.preferences)}
        </Text>
        <Text className="text-sm text-muted-foreground">
          {t($ => $.core.settings.preferencesDescription)}
        </Text>
      </View>
      <View
        accessibilityRole="radiogroup"
        accessibilityLabel={t($ => $.core.settings.language)}
        className="gap-2"
      >
        {LOCALES.map(locale => {
          const selected = locale === user.locale;
          return (
            <Pressable
              key={locale}
              accessibilityRole="radio"
              accessibilityState={{checked: selected}}
              disabled={save.isPending}
              onPress={() => save.mutate({body: {locale}})}
              className={`h-11 justify-center rounded-lg border px-4 focus:ring-2 focus:ring-ring ${selected ? 'border-primary bg-accent' : 'border-border active:bg-accent'}`}
            >
              <Text className="text-base text-foreground">{localeNames[locale]}</Text>
            </Pressable>
          );
        })}
      </View>
      {save.isError && (
        <Text accessibilityLiveRegion="polite" className="text-destructive">
          {t($ => $.core.errors.somethingWentWrong)}
        </Text>
      )}
    </Screen>
  );
}
