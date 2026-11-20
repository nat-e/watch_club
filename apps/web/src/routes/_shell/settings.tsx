import {useMutation} from '@tanstack/react-query';
import {createFileRoute} from '@tanstack/react-router';
import {useCurrentUser} from '@watchclub/core/accounts/current-user';
import {
  savePreferencesMutation,
  useTrackLanguageOptions,
} from '@watchclub/core/accounts/preferences';
import {TMDB_LOGO_SVG, TMDB_URL} from '@watchclub/core/contents/tmdb';
import {useInstanceName} from '@watchclub/core/instance';
import {LOCALES, useLocaleNames} from '@watchclub/core/l10n';
import type {ReactNode} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {useAppForm} from '@/components/forms/form';
import {MultiSelectField} from '@/components/forms/multi-select-field';
import {SelectField} from '@/components/forms/select-field';
import {Page} from '@/components/layouts/page';
import {Card, CardContent, CardDescription, CardHeader} from '@/components/ui/card';

/** Settings, where Users choose their User Preferences. */
export const Route = createFileRoute('/_shell/settings')({component: Settings});

function Settings() {
  const {t} = useTranslation('core');
  return (
    <Page title={t($ => $.core.settings.title)}>
      <p className="max-w-readable leading-7 text-muted-foreground">
        {t($ => $.core.settings.description)}
      </p>
      <LanguageSection />
      <AudioAndSubtitlesSection />
      <AboutSection />
    </Page>
  );
}

/** The User's Locale, which the app switches to once saved. */
function LanguageSection() {
  const {t, i18n} = useTranslation('core');
  const localeNames = useLocaleNames();
  const instanceName = useInstanceName();
  const user = useCurrentUser();
  const save = useMutation(savePreferencesMutation);
  const form = useAppForm({
    defaultValues: {locale: user.preferences.locale},
    onSubmit: async ({value, createValidationError}) => {
      try {
        await save.mutateAsync({user: user.id, changes: {locale: value.locale}});
      } catch {
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      // In the new Locale, as the page now is, rather than in this render's
      const tNew = i18n.getFixedT(value.locale, 'core');
      toast.success(tNew($ => $.core.settings.languageSaved));
      return null;
    },
  });

  return (
    <SettingsSection
      title={t($ => $.core.settings.preferences)}
      description={t($ => $.core.settings.preferencesDescription, {name: instanceName})}
    >
      <form.AppForm>
        <form.Form className="flex flex-col items-start gap-6 sm:max-w-sm">
          <form.Field name="locale">
            {field => (
              <SelectField
                label={t($ => $.core.settings.language)}
                options={LOCALES.map(locale => ({value: locale, label: localeNames[locale]}))}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.FormError />
          <form.SubmitButton className="w-full sm:w-auto">
            {t($ => $.core.settings.save)}
          </form.SubmitButton>
        </form.Form>
      </form.AppForm>
    </SettingsSection>
  );
}

/** The audio and subtitles videos start with. */
function AudioAndSubtitlesSection() {
  const {t} = useTranslation(['core', 'web']);
  const options = useTrackLanguageOptions();
  const user = useCurrentUser();
  const save = useMutation(savePreferencesMutation);
  const form = useAppForm({
    // biome-ignore-start lint/style/useNamingConvention: the API's fields
    defaultValues: {
      audio_language: user.preferences.audio_language,
      subtitle_language: user.preferences.subtitle_language,
      languages_without_subtitles: user.preferences.languages_without_subtitles,
    },
    // biome-ignore-end lint/style/useNamingConvention: the API's fields
    onSubmit: async ({value, createValidationError}) => {
      try {
        await save.mutateAsync({user: user.id, changes: value});
      } catch {
        return createValidationError(t($ => $.core.errors.somethingWentWrong));
      }
      toast.success(t($ => $.core.settings.audioAndSubtitlesSaved));
      return null;
    },
  });

  return (
    <SettingsSection
      title={t($ => $.core.settings.audioAndSubtitles)}
      description={t($ => $.core.settings.audioAndSubtitlesDescription)}
    >
      <form.AppForm>
        <form.Form className="flex flex-col items-start gap-6 sm:max-w-sm">
          <form.Field name="audio_language">
            {field => (
              <SelectField
                label={t($ => $.core.settings.audio)}
                options={options.audio}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.Field name="subtitle_language">
            {field => (
              <SelectField
                label={t($ => $.core.settings.subtitles)}
                options={options.subtitles}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.Field name="languages_without_subtitles">
            {field => (
              <MultiSelectField
                label={t($ => $.core.settings.languagesWithoutSubtitles)}
                description={t($ => $.core.settings.languagesWithoutSubtitlesDescription)}
                placeholder={t($ => $.web.settings.addLanguage)}
                noMatch={t($ => $.web.settings.noLanguageMatches)}
                options={options.languages}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.FormError />
          <form.SubmitButton className="w-full sm:w-auto">
            {t($ => $.core.settings.save)}
          </form.SubmitButton>
        </form.Form>
      </form.AppForm>
    </SettingsSection>
  );
}

/**
 * TMDB's notice and logo, which its terms require: the exact notice, and the logo unaltered and
 * less prominent than the Instance's name.
 */
function AboutSection() {
  const {t} = useTranslation('core');
  return (
    <SettingsSection
      title={t($ => $.core.settings.about)}
      description={t($ => $.core.settings.tmdbNotice)}
    >
      <a
        href={TMDB_URL}
        target="_blank"
        rel="noopener noreferrer"
        className="inline-flex min-h-11 items-center"
      >
        <img
          src={`data:image/svg+xml,${encodeURIComponent(TMDB_LOGO_SVG)}`}
          alt={t($ => $.core.settings.tmdbLogo)}
          className="h-4"
        />
      </a>
    </SettingsSection>
  );
}

/** A card of Settings, with its title and what its preferences do. */
function SettingsSection({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <section>
      <Card>
        <CardHeader>
          <h2 className="font-heading text-xl font-semibold tracking-tight">{title}</h2>
          <CardDescription className="max-w-readable leading-6">{description}</CardDescription>
        </CardHeader>
        <CardContent>{children}</CardContent>
      </Card>
    </section>
  );
}
