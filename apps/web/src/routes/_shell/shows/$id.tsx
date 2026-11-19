import {createFileRoute} from '@tanstack/react-router';
import {ContentPage, ContentPagePending, loadContent} from '@/components/contents/content-page';

/** A TV Show's page. */
export const Route = createFileRoute('/_shell/shows/$id')({
  loader: ({context, params}) => loadContent(context.queryClient, 'tv_show', params.id),
  pendingComponent: ContentPagePending,
  component: TvShow,
});

function TvShow() {
  return <ContentPage externalContentId={Route.useLoaderData()} />;
}
