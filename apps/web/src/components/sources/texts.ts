/**
 * The texts of Sources in the app's language: the names of their types and Media Types, and the
 * errors in their Source Configuration.
 */
import type {ConnectionError, FolderError, MediaType, ServarrApp} from '@watchclub/api';
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
