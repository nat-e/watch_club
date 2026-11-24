/**
 * The texts of Sources in the app's language: the names of their types and Media Types, the errors
 * in their Source Configuration, and the texts of their Media Imports.
 */
import type {
  ConnectionError,
  FilesToImport,
  FolderError,
  MediaImportFailure,
  MediaImportState,
  MediaImportTrigger,
  MediaType,
  ServarrApp,
} from '@watchclub/api';
import type {SourceType} from '@watchclub/core/sources/sources';
import {useTranslation} from 'react-i18next';

/** The texts of a Source Type. */
interface SourceTypeTexts {
  name: string;
  /** The purpose of its Sources */
  description: string;
  /** The suggested action when it has none */
  empty: string;
}

/** Returns the texts of each Source Type. */
export function useSourceTypeTexts(): Record<SourceType, SourceTypeTexts> {
  const {t} = useTranslation('web');
  return {
    filesystem: {
      name: t($ => $.web.sources.types.filesystem.name),
      description: t($ => $.web.sources.types.filesystem.description),
      empty: t($ => $.web.sources.types.filesystem.empty),
    },
    radarr: {
      name: t($ => $.web.sources.types.radarr.name),
      description: t($ => $.web.sources.types.radarr.description),
      empty: t($ => $.web.sources.types.radarr.empty),
    },
    sonarr: {
      name: t($ => $.web.sources.types.sonarr.name),
      description: t($ => $.web.sources.types.sonarr.description),
      empty: t($ => $.web.sources.types.sonarr.empty),
    },
    sportarr: {
      name: t($ => $.web.sources.types.sportarr.name),
      description: t($ => $.web.sources.types.sportarr.description),
      empty: t($ => $.web.sources.types.sportarr.empty),
    },
  };
}

/** Returns the name of each Media Type, such as "Movie". */
export function useMediaTypeNames(): Record<MediaType, string> {
  const {t} = useTranslation('web');
  return {
    movie: t($ => $.web.sources.mediaTypes.movie),
    // biome-ignore-start lint/style/useNamingConvention: the API's Media Types are snake_case
    tv_show_episode: t($ => $.web.sources.mediaTypes.tvShowEpisode),
    sports_event: t($ => $.web.sources.mediaTypes.sportsEvent),
    // biome-ignore-end lint/style/useNamingConvention: the API's Media Types are snake_case
  };
}

/** Returns the functions that say what's wrong with a Source Configuration, and what to do. */
export function useErrorMessages() {
  const {t} = useTranslation('web');
  const typeTexts = useSourceTypeTexts();

  return {
    folder(error: FolderError): string {
      switch (error.code) {
        case 'not_absolute':
          return t($ => $.web.sources.folderErrors.notAbsolute);
        case 'not_found':
          return t($ => $.web.sources.folderErrors.notFound);
      }
    },

    connection(error: ConnectionError, app: ServarrApp): string {
      const name = typeTexts[app].name;
      switch (error.code) {
        case 'invalid_servarr_url':
          return t($ => $.web.sources.connectionErrors.invalidServarrUrl, {app: name});
        case 'invalid_api_key':
          return t($ => $.web.sources.connectionErrors.invalidApiKey, {app: name});
      }
    },

    /** Returns the message that the app has no quality profile to choose. */
    noQualityProfiles(app: ServarrApp): string {
      return t($ => $.web.sources.qualityProfileErrors.noneInApp, {app: typeTexts[app].name});
    },

    /** Returns the message that the app has no root folder to choose. */
    noRootFolders(app: ServarrApp): string {
      return t($ => $.web.sources.rootFolderErrors.noneInApp, {app: typeTexts[app].name});
    },
  };
}

/** The texts of a choice of the files an import handles. */
interface FilesToImportTexts {
  name: string;
  /** The files it handles */
  description: string;
  /** Its name in a Source's history */
  shortName: string;
}

/** Returns the texts of each choice of the files an import handles. */
export function useFilesToImportTexts(): Record<FilesToImport, FilesToImportTexts> {
  const {t} = useTranslation('web');
  return {
    new: {
      name: t($ => $.web.mediaImports.filesToImport.new.name),
      description: t($ => $.web.mediaImports.filesToImport.new.description),
      shortName: t($ => $.web.mediaImports.filesToImport.new.shortName),
    },
    // biome-ignore lint/style/useNamingConvention: the API's choices are snake_case
    new_and_unmatched: {
      name: t($ => $.web.mediaImports.filesToImport.newAndUnmatched.name),
      description: t($ => $.web.mediaImports.filesToImport.newAndUnmatched.description),
      shortName: t($ => $.web.mediaImports.filesToImport.newAndUnmatched.shortName),
    },
    all: {
      name: t($ => $.web.mediaImports.filesToImport.all.name),
      description: t($ => $.web.mediaImports.filesToImport.all.description),
      shortName: t($ => $.web.mediaImports.filesToImport.all.shortName),
    },
  };
}

/** Returns the name of each state of an import, such as "In progress". */
export function useMediaImportStateNames(): Record<MediaImportState, string> {
  const {t} = useTranslation('web');
  return {
    waiting: t($ => $.web.mediaImports.states.waiting),
    running: t($ => $.web.mediaImports.states.running),
    completed: t($ => $.web.mediaImports.states.completed),
    failed: t($ => $.web.mediaImports.states.failed),
  };
}

/** Returns the name of what started each import: a person, or the schedule. */
export function useMediaImportTriggerNames(): Record<MediaImportTrigger, string> {
  const {t} = useTranslation('web');
  return {
    manual: t($ => $.web.mediaImports.triggers.manual),
    scheduled: t($ => $.web.mediaImports.triggers.scheduled),
  };
}

/** Returns the function that says why an import of a Source of the type failed, and what to do. */
export function useMediaImportFailureMessage(): (
  failure: MediaImportFailure,
  type: SourceType,
) => string {
  const {t} = useTranslation('web');
  const typeTexts = useSourceTypeTexts();

  return (failure, type) => {
    const name = typeTexts[type].name;
    switch (failure) {
      case 'invalid_servarr_url':
        return t($ => $.web.mediaImports.failures.invalidServarrUrl, {app: name});
      case 'invalid_api_key':
        return t($ => $.web.mediaImports.failures.invalidApiKey, {app: name});
      case 'internal_error':
        return t($ => $.web.mediaImports.failures.internalError);
      case 'interrupted':
        return t($ => $.web.mediaImports.failures.interrupted);
    }
  };
}
