import {createFileRoute} from '@tanstack/react-router';
import {ContentPage, loadContent} from '@/components/contents/content-page';

/** A Book's page. */
export const Route = createFileRoute('/_shell/books/$id')({
  loader: ({context, params}) => loadContent(context.queryClient, 'book', params.id),
  component: Book,
});

function Book() {
  return <ContentPage id={Route.useLoaderData()} />;
}
