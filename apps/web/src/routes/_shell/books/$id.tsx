import {createFileRoute} from '@tanstack/react-router';
import {ContentPage, ContentPagePending, loadContent} from '@/components/contents/content-page';

/** A Book's page. */
export const Route = createFileRoute('/_shell/books/$id')({
  loader: ({context, params}) => loadContent(context.queryClient, 'book', params.id),
  pendingComponent: ContentPagePending,
  component: Book,
});

function Book() {
  return <ContentPage externalContentId={Route.useLoaderData()} />;
}
