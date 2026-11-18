/**
 * Content: the Movies and TV Shows Users watch and talk about, as both apps show them.
 */
import {queryOptions} from '@tanstack/react-query';
import {type ContentId, type ContentType, getContentOptions} from '@watchclub/api';
import {useTranslation} from 'react-i18next';

/** Returns the query of a Content, with its title in the User's language. */
export function contentQuery({content_type, external_id}: ContentId) {
  // biome-ignore lint/style/useNamingConvention: the API's path parameters are snake_case
  return queryOptions(getContentOptions({path: {content_type, external_id}}));
}

/** Returns the name of each type of Content in the app's language, such as "Movie". */
export function useContentTypeNames(): Record<ContentType, string> {
  const {t} = useTranslation('core');
  // biome-ignore lint/style/useNamingConvention: the API's Content Types are snake_case
  return {movie: t($ => $.core.contentTypes.movie), tv_show: t($ => $.core.contentTypes.tvShow)};
}
