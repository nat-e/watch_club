/**
 * Content: the Movies and TV Shows Users watch and talk about, as both apps show them.
 */
import {queryOptions} from '@tanstack/react-query';
import {type ContentId, type ContentType, getContentOptions} from '@watchclub/api';
import {useTranslation} from 'react-i18next';

/** The largest TMDB ID the API takes */
const MAX_TMDB_ID = 2 ** 32 - 1;

/**
 * Returns the TMDB ID that a screen's URL holds, or null when it can't be one, so the screen shows
 * that it doesn't exist.
 */
export function parseTmdbId(text: string): number | null {
  const id = Number(text);
  return /^\d+$/.test(text) && id <= MAX_TMDB_ID ? id : null;
}

/** Returns the query of a Content, with its title in the User's language. */
export function contentQuery({content_type, tmdb_id}: ContentId) {
  // biome-ignore lint/style/useNamingConvention: the API's path parameters are snake_case
  return queryOptions(getContentOptions({path: {content_type, tmdb_id}}));
}

/** Returns the name of each type of Content in the app's language, such as "Movie". */
export function useContentTypeNames(): Record<ContentType, string> {
  const {t} = useTranslation('core');
  // biome-ignore lint/style/useNamingConvention: the API's Content Types are snake_case
  return {movie: t($ => $.core.contentTypes.movie), tv_show: t($ => $.core.contentTypes.tvShow)};
}

/** TMDB's widths of posters, in pixels */
const POSTER_WIDTHS = [92, 154, 185, 342, 500, 780] as const;

/**
 * Returns the URL of a poster on TMDB's image server, from its path, in the smallest size that
 * stays sharp at `width` points on screens of up to 3 pixels per point.
 */
export function posterUrl(path: string, width: number): string {
  const size = POSTER_WIDTHS.find(each => each >= width * 3);
  return `https://image.tmdb.org/t/p/${size ? `w${size}` : 'original'}${path}`;
}
