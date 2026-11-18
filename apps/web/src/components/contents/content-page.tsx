import {type QueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {linkOptions, notFound} from '@tanstack/react-router';
import {type ContentId, type ContentType, hasCode} from '@watchclub/api';
import {contentQuery, parseTmdbId} from '@watchclub/core/contents/content';
import {Page} from '@/components/layouts/page';

/** Returns the options of a link to the Content's page. */
export function contentLink({content_type, tmdb_id}: ContentId) {
  const params = {id: String(tmdb_id)};
  switch (content_type) {
    case 'movie':
      return linkOptions({to: '/movies/$id', params});
    case 'tv_show':
      return linkOptions({to: '/shows/$id', params});
  }
}

/**
 * Loads the Content of a page's URL, from its type and the TMDB ID in the URL, or shows that the
 * page doesn't exist when TMDB has no such Content.
 */
export async function loadContent(
  queryClient: QueryClient,
  contentType: ContentType,
  idParam: string,
): Promise<ContentId> {
  const tmdbId = parseTmdbId(idParam);
  if (tmdbId === null) {
    throw notFound();
  }
  // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
  const id: ContentId = {content_type: contentType, tmdb_id: tmdbId};
  try {
    await queryClient.ensureQueryData(contentQuery(id));
  } catch (error) {
    if (hasCode(error, 'not_found')) {
      throw notFound();
    }
    throw error;
  }
  return id;
}

/** A Content's page. For now, it only shows its title, until the Content pages are ported. */
export function ContentPage({id}: {id: ContentId}) {
  const {data: content} = useSuspenseQuery(contentQuery(id));
  return <Page title={content.title} />;
}
