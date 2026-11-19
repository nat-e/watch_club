import {createFileRoute} from '@tanstack/react-router';
import {ContentPage, ContentPagePending, loadContent} from '@/components/contents/content-page';

/** A Movie's page. */
export const Route = createFileRoute('/_shell/movies/$id')({
  loader: ({context, params}) => loadContent(context.queryClient, 'movie', params.id),
  pendingComponent: ContentPagePending,
  component: Movie,
});

function Movie() {
  return <ContentPage externalContentId={Route.useLoaderData()} />;
}
