import {createFileRoute} from '@tanstack/react-router';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {useSavePreferences} from '@watchclub/core/accounts/preferences';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import {useId} from 'react';
import {useTranslation} from 'react-i18next';
import {useAppForm} from '@/components/forms/form';
import {Page} from '@/components/layouts/page';
import {Card, CardContent, CardDescription, CardHeader} from '@/components/ui/card';
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
    <Page title={t($ => $.core.settings.title)}>
      <p className="max-w-readable leading-7 text-muted-foreground">
        {t($ => $.core.settings.description)}
      </p>
      <section>
        <Card>
          <CardHeader>
            <h2 className="font-heading text-xl font-semibold tracking-tight">
              {t($ => $.core.settings.preferences)}
            </h2>
            <CardDescription className="max-w-readable leading-6">
              {t($ => $.core.settings.preferencesDescription)}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form.AppForm>
              <form.Form className="flex flex-col items-start gap-6 sm:max-w-sm">
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
                <form.SubmitButton className="w-full sm:w-auto">
                  {t($ => $.core.settings.save)}
                </form.SubmitButton>
              </form.Form>
            </form.AppForm>
          </CardContent>
        </Card>
      </section>
    </Page>
  );
}
