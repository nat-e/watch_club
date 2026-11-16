import {createFileRoute} from '@tanstack/react-router';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useSavePreferences} from '@watchclub/core/accounts/preferences';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {useId} from 'react';
import {useTranslation} from 'react-i18next';
import {useAppForm} from '@/components/form';
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
  const user = useCurrentUser();
  const localeId = useId();
  const save = useSavePreferences();
  const form = useAppForm({
    defaultValues: {locale: user.locale},
    onSubmit: async ({value, createValidationError}) => {
      try {
        await save.mutateAsync({locale: value.locale});
      } catch {
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      return null;
    },
  });

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
        <form.AppForm>
          <form.Form className="flex flex-col items-start gap-4 sm:max-w-sm">
            <form.Field name="locale">
              {field => (
                <Field>
                  <FieldLabel htmlFor={localeId}>{t($ => $.core.settings.language)}</FieldLabel>
                  <Select
                    items={locales}
                    value={field.value}
                    onValueChange={value => {
                      if (value) {
                        field.handleChange(value);
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
              )}
            </form.Field>
            <form.FormError />
            <form.SubmitButton>{t($ => $.core.settings.save)}</form.SubmitButton>
          </form.Form>
        </form.AppForm>
      </section>
    </>
  );
}
