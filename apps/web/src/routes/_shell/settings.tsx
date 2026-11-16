import {createFileRoute} from '@tanstack/react-router';
import {useSavePreferences} from '@watchclub/core/accounts/preferences';
import {useUser} from '@watchclub/core/accounts/session';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {type FormEvent, useId, useState} from 'react';
import {useTranslation} from 'react-i18next';
import {SomethingWentWrong} from '@/components/something-went-wrong';
import {Button} from '@/components/ui/button';
import {Field, FieldLabel} from '@/components/ui/field';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

/** Settings, where Users choose their User Preferences. */
export const Route = createFileRoute('/_shell/settings')({component: Settings});

function Settings() {
  const {t} = useTranslation('core');
  const localeNames = useLocaleNames();
  const user = useUser();
  const localeId = useId();
  const [locale, setLocale] = useState(user.locale);
  const save = useSavePreferences();

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    save.mutate({body: {locale}});
  }

  const locales = LOCALES.map(value => ({value, label: localeNames[value]}));

  return (
    <>
      <div className="flex flex-col gap-1">
        <h1 className="font-heading text-2xl font-semibold">{t($ => $.core.settings.title)}</h1>
        <p className="text-muted-foreground">{t($ => $.core.settings.description)}</p>
      </div>
      <section className="flex flex-col gap-4">
        <div className="flex flex-col gap-1">
          <h2 className="font-heading text-lg font-semibold">
            {t($ => $.core.settings.preferences)}
          </h2>
          <p className="text-sm text-muted-foreground">
            {t($ => $.core.settings.preferencesDescription)}
          </p>
        </div>
        <form onSubmit={submit} className="flex flex-col items-start gap-4 sm:max-w-sm">
          <Field>
            <FieldLabel htmlFor={localeId}>{t($ => $.core.settings.language)}</FieldLabel>
            <Select
              items={locales}
              value={locale}
              onValueChange={value => {
                if (value) {
                  setLocale(value);
                }
              }}
            >
              <SelectTrigger id={localeId} className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {locales.map(({value, label}) => (
                  <SelectItem key={value} value={value}>
                    {label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>
          {save.isError && <SomethingWentWrong />}
          <Button type="submit" disabled={save.isPending}>
            {t($ => $.core.settings.save)}
          </Button>
        </form>
      </section>
    </>
  );
}
