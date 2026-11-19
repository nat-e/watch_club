import {type QueryClient, useSuspenseQuery} from '@tanstack/react-query';
import {linkOptions, notFound} from '@tanstack/react-router';
import {type ContentType, type ExternalContentId, hasCode} from '@watchclub/api';
import {contentQuery} from '@watchclub/core/contents/content';
import {Page} from '@/components/layouts/page';

/** Returns the options of a link to the Content's page. */
export function contentLink({content_type, external_id}: ExternalContentId) {
  const params = {id: external_id};
  switch (content_type) {
    case 'movie':
      return linkOptions({to: '/movies/$id', params});
    case 'tv_show':
      return linkOptions({to: '/shows/$id', params});
    case 'sports_event':
      return linkOptions({to: '/sports/$id', params});
    case 'book':
      return linkOptions({to: '/books/$id', params});
  }
}

/**
 * Loads the Content of a page's URL, from its type and the External ID in the URL, or shows that
 * the page doesn't exist when there's no such Content.
 */
export async function loadContent(
  queryClient: QueryClient,
  contentType: ContentType,
  idParam: string,
): Promise<ExternalContentId> {
  // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
  const externalContentId: ExternalContentId = {content_type: contentType, external_id: idParam};
  try {
    await queryClient.ensureQueryData(contentQuery(externalContentId));
  } catch (error) {
    if (hasCode(error, 'not_found')) {
      throw notFound();
    }
    throw error;
  }
  return externalContentId;
}

/** A Content's page. For now, it only shows its title, until the Content pages are ported. */
export function ContentPage({externalContentId}: {externalContentId: ExternalContentId}) {
  const {data: content} = useSuspenseQuery(contentQuery(externalContentId));
  return <Page title={content.title} />;
}
