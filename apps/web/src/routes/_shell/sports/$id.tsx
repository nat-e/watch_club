import {createFileRoute} from '@tanstack/react-router';
import {ContentPage, loadContent} from '@/components/contents/content-page';

/** A Sports Event's page. */
export const Route = createFileRoute('/_shell/sports/$id')({
  loader: ({context, params}) => loadContent(context.queryClient, 'sports_event', params.id),
  component: SportsEvent,
});

function SportsEvent() {
  return <ContentPage externalContentId={Route.useLoaderData()} />;
}
