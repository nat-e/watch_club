import {useMutation} from '@tanstack/react-query';
import type {QualityProfile, ServarrApp, SourceCheck} from '@watchclub/api';
import {
  ConnectionRefusedError,
  checkExistingSourceApp,
  checkNewSourceApp,
  InvalidServarrConfigurationError,
  type ServarrSource,
  saveSourceMutation,
} from '@watchclub/core/sources/sources';
import * as icons from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {toast} from 'sonner';
import {useAppForm} from '@/components/forms/form';
import {SelectField} from '@/components/forms/select-field';
import {useErrorMessages, useSourceTypeTexts} from '@/components/sources/texts';
import {Button} from '@/components/ui/button';
import {
  DialogClose,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

/** The address each app listens at in a usual Docker setup, as an example */
const URL_EXAMPLES: Record<ServarrApp, string> = {
  radarr: 'http://radarr:7878',
  sonarr: 'http://sonarr:8989',
  sportarr: 'http://sportarr:1867',
};

/**
 * The address and API key WatchClub calls an app with. An empty key keeps the Source's saved one,
 * which the server never sends.
 */
interface Credentials {
  url: string;
  apiKey: string;
}

/** Returns the API key to send: null when the field is empty, which keeps the saved one. */
function apiKeyToSend(credentials: Credentials): string | null {
  return credentials.apiKey.trim() === '' ? null : credentials.apiKey;
}

/**
 * The form of a Radarr, Sonarr or Sportarr Source in a dialog, which creates one of the app, or
 * edits `source`. It connects to the app first, then lets the Instance Administrator choose one of
 * its quality profiles and root folders for the Source's requests.
 */
export function ServarrSourceForm({
  onSaved,
  ...target
}: ({app: ServarrApp; source?: never} | {source: ServarrSource; app?: never}) & {
  onSaved: () => void;
}) {
  const {source} = target;
  const app = source === undefined ? target.app : source.type;
  const [credentials, setCredentials] = useState<Credentials>({
    url: source?.url ?? '',
    apiKey: '',
  });
  // Null until the app answers the check, with its quality profiles and root folders
  const [sourceCheck, setSourceCheck] = useState<SourceCheck | null>(null);

  if (sourceCheck === null) {
    return (
      <ConnectionStep
        app={app}
        source={source}
        credentials={credentials}
        onConnected={(connectedCredentials, newSourceCheck) => {
          setCredentials(connectedCredentials);
          setSourceCheck(newSourceCheck);
        }}
      />
    );
  }
  return (
    <QualityProfileAndRootFolderStep
      app={app}
      source={source}
      credentials={credentials}
      qualityProfiles={sourceCheck.quality_profiles}
      rootFolders={sourceCheck.root_folders}
      onBack={() => {
        setSourceCheck(null);
      }}
      onSaved={onSaved}
    />
  );
}

/**
 * The first step: the app's address and API key, which the server checks. Editing `source`, an
 * empty API key keeps its saved one.
 */
function ConnectionStep({
  app,
  source,
  credentials,
  onConnected,
}: {
  app: ServarrApp;
  source?: ServarrSource;
  credentials: Credentials;
  onConnected: (credentials: Credentials, sourceCheck: SourceCheck) => void;
}) {
  const {t} = useTranslation(['web', 'core']);
  const name = useSourceTypeTexts()[app].name;
  const errorMessages = useErrorMessages();
  const form = useAppForm({
    defaultValues: credentials,
    validators: [
      {
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          if (value.url.trim() === '') {
            errors.fields.url = t($ => $.web.sources.servarrForm.enterUrl);
          }
          if (source === undefined && apiKeyToSend(value) === null) {
            errors.fields.apiKey = t($ => $.web.sources.servarrForm.enterApiKey);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      let sourceCheck: SourceCheck;
      try {
        // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
        sourceCheck =
          source === undefined
            ? await checkNewSourceApp({type: app, url: value.url, api_key: value.apiKey})
            : await checkExistingSourceApp(source.id, {
                url: value.url,
                api_key: apiKeyToSend(value),
              });
        // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
      } catch (error) {
        if (!(error instanceof ConnectionRefusedError)) {
          return createValidationError(t($ => $.core.errors.somethingWentWrong));
        }
        const message = errorMessages.connection(error.cause, app);
        const isAboutTheKey = error.cause.code === 'invalid_api_key';
        return createValidationError({
          fields: isAboutTheKey ? {apiKey: message} : {url: message},
        });
      }
      onConnected(value, sourceCheck);
      return null;
    },
  });

  return (
    <>
      <DialogHeader>
        <DialogTitle>{t($ => $.web.sources.servarrForm.connectTitle, {app: name})}</DialogTitle>
        <DialogDescription>
          {t($ => $.web.sources.servarrForm.connectDescription, {app: name})}
        </DialogDescription>
      </DialogHeader>
      <form.AppForm>
        <form.Form className="flex flex-col gap-6">
          <form.Field name="url">
            {field => (
              <field.TextField
                label={t($ => $.web.sources.servarrForm.url, {app: name})}
                hint={t($ => $.web.sources.servarrForm.urlHint, {app: name})}
                placeholder={URL_EXAMPLES[app]}
                inputMode="url"
                autoCapitalize="none"
                autoCorrect="off"
                autoComplete="off"
                spellCheck={false}
                className="font-mono"
              />
            )}
          </form.Field>
          <form.Field name="apiKey">
            {field => (
              <field.TextField
                label={t($ => $.web.sources.servarrForm.apiKey)}
                hint={
                  source === undefined
                    ? t($ => $.web.sources.servarrForm.apiKeyHint, {app: name})
                    : t($ => $.web.sources.servarrForm.apiKeyKeepHint, {app: name})
                }
                type="password"
                autoComplete="off"
                className="font-mono"
              />
            )}
          </form.Field>
          <form.FormError />
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>
              {t($ => $.core.controls.cancel)}
            </DialogClose>
            <form.SubmitButton pending={t($ => $.web.sources.servarrForm.connecting)}>
              {t($ => $.web.sources.servarrForm.connect)}
            </form.SubmitButton>
          </DialogFooter>
        </form.Form>
      </form.AppForm>
    </>
  );
}

/**
 * The second step: the quality profile and root folder of the Source's requests, among the app's,
 * and where WatchClub sees the root folder.
 */
function QualityProfileAndRootFolderStep({
  app,
  source,
  credentials,
  qualityProfiles,
  rootFolders,
  onBack,
  onSaved,
}: {
  app: ServarrApp;
  source?: ServarrSource;
  credentials: Credentials;
  qualityProfiles: QualityProfile[];
  /** Their paths, as the app sees them */
  rootFolders: string[];
  onBack: () => void;
  onSaved: () => void;
}) {
  const {t} = useTranslation(['web', 'core']);
  const save = useMutation(saveSourceMutation);
  const errorMessages = useErrorMessages();
  // The Source's quality profile and root folder when the app still has them, or else its first ones
  const profileIds = qualityProfiles.map(profile => profile.id);
  const savedProfileId = source?.quality_profile.id;
  const qualityProfileId =
    savedProfileId !== undefined && profileIds.includes(savedProfileId)
      ? savedProfileId
      : (profileIds[0] ?? null);
  const savedRootFolder = source?.root_folder_path;
  const rootFolderPath =
    savedRootFolder !== undefined && rootFolders.includes(savedRootFolder)
      ? savedRootFolder
      : (rootFolders[0] ?? null);
  const form = useAppForm({
    defaultValues: {
      qualityProfileId,
      rootFolderPath,
      localRootFolderPath: source?.local_root_folder_path ?? '',
    },
    validators: [
      {
        triggers: [],
        run: ({value, createErrorMap}) => {
          const errors = createErrorMap();
          // Only when the app has none
          if (value.qualityProfileId === null) {
            errors.fields.qualityProfileId = errorMessages.noQualityProfiles(app);
          }
          if (value.rootFolderPath === null) {
            errors.fields.rootFolderPath = errorMessages.noRootFolders(app);
          }
          return errors;
        },
      },
    ],
    onSubmit: async ({value, createValidationError}) => {
      if (value.qualityProfileId === null || value.rootFolderPath === null) {
        return null;
      }
      const localRootFolderPath = value.localRootFolderPath.trim();
      try {
        await save.mutateAsync({
          // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
          configuration: {
            type: app,
            url: credentials.url,
            api_key: apiKeyToSend(credentials),
            quality_profile_id: value.qualityProfileId,
            root_folder_path: value.rootFolderPath,
            local_root_folder_path: localRootFolderPath === '' ? null : localRootFolderPath,
          },
          // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
          id: source?.id,
        });
      } catch (error) {
        if (!(error instanceof InvalidServarrConfigurationError)) {
          return createValidationError(t($ => $.core.errors.somethingWentWrong));
        }
        const {cause} = error;
        switch (cause.part) {
          case 'connection':
            // The URL and API key are in the step before
            return createValidationError(errorMessages.connection(cause, app));
          case 'quality_profile':
            return createValidationError({
              fields: {qualityProfileId: errorMessages.qualityProfileNotFound(app)},
            });
          case 'root_folder':
            return createValidationError({
              fields: {rootFolderPath: errorMessages.rootFolderNotFound(app)},
            });
          case 'local_root_folder':
            return createValidationError({
              fields: {localRootFolderPath: errorMessages.folder(cause)},
            });
        }
      }
      toast.success(
        source === undefined ? t($ => $.web.sources.configured) : t($ => $.web.sources.updated),
      );
      onSaved();
      return null;
    },
  });

  return (
    <>
      <DialogHeader>
        <DialogTitle>{t($ => $.web.sources.servarrForm.configureTitle)}</DialogTitle>
        <DialogDescription>
          {t($ => $.web.sources.servarrForm.configureDescription)}
        </DialogDescription>
      </DialogHeader>
      <form.AppForm>
        <form.Form className="flex flex-col gap-6">
          <form.Field name="qualityProfileId">
            {field => (
              <SelectField
                label={t($ => $.web.sources.servarrForm.qualityProfile)}
                description={t($ => $.web.sources.servarrForm.qualityProfileHint)}
                error={field.errors[0]?.message}
                options={qualityProfiles.map(profile => ({
                  value: profile.id,
                  label: profile.name,
                }))}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.Field name="rootFolderPath">
            {field => (
              <SelectField
                label={t($ => $.web.sources.servarrForm.rootFolder)}
                description={t($ => $.web.sources.servarrForm.rootFolderHint)}
                error={field.errors[0]?.message}
                options={rootFolders.map(path => ({value: path, label: path}))}
                value={field.value}
                onChange={field.handleChange}
              />
            )}
          </form.Field>
          <form.Subscribe selector={state => state.values.rootFolderPath}>
            {rootFolder => (
              <form.Field name="localRootFolderPath">
                {field => (
                  <field.TextField
                    label={t($ => $.web.sources.servarrForm.localRootFolder)}
                    hint={t($ => $.web.sources.servarrForm.localRootFolderHint)}
                    placeholder={rootFolder ?? undefined}
                    autoComplete="off"
                    spellCheck={false}
                    className="font-mono"
                  />
                )}
              </form.Field>
            )}
          </form.Subscribe>
          <form.FormError />
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onBack}>
              <icons.ArrowLeftIcon />
              {t($ => $.core.controls.back)}
            </Button>
            <form.SubmitButton>
              {source === undefined
                ? t($ => $.web.sources.servarrForm.add)
                : t($ => $.web.sources.servarrForm.save)}
            </form.SubmitButton>
          </DialogFooter>
        </form.Form>
      </form.AppForm>
    </>
  );
}
