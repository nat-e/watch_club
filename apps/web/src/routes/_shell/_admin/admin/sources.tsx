import {useSuspenseQuery} from '@tanstack/react-query';
import {createFileRoute} from '@tanstack/react-router';
import {SOURCE_TYPES, sourcesQuery} from '@watchclub/core/sources/sources';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';
import {SourceTypeSection} from '@/components/sources/source-type-section';

/** Sources, where the Instance Administrator manages where WatchClub imports Media Files from. */
export const Route = createFileRoute('/_shell/_admin/admin/sources')({
  loader: ({context}) => context.queryClient.ensureQueryData(sourcesQuery),
  component: Sources,
});

function Sources() {
  const {t} = useTranslation('web');
  const {data: sources} = useSuspenseQuery(sourcesQuery);
  return (
    <Page title={t($ => $.web.sources.title)}>
      <p className="max-w-readable leading-7 text-muted-foreground">
        {t($ => $.web.sources.description)}
      </p>
      {SOURCE_TYPES.map(type => (
        <SourceTypeSection
          key={type}
          type={type}
          sources={sources.filter(source => source.type === type)}
        />
      ))}
    </Page>
  );
}
