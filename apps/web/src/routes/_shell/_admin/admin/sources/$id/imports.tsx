import {useSuspenseQuery} from '@tanstack/react-query';
import {createFileRoute, Link, notFound} from '@tanstack/react-router';
import {importsFiles, mediaImportsQuery} from '@watchclub/core/sources/media-imports';
import {isServarrSource, sourcesQuery} from '@watchclub/core/sources/sources';
import {ArrowLeftIcon, HistoryIcon, PlayIcon} from 'lucide-react';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {Page} from '@/components/layouts/page';
import {ImportDialog} from '@/components/sources/import-dialog';
import {MediaImportsTable} from '@/components/sources/media-imports-table';
import {useSourceTypeTexts} from '@/components/sources/texts';
import {Badge} from '@/components/ui/badge';
import {Button, buttonVariants} from '@/components/ui/button';
import {Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle} from '@/components/ui/empty';

/**
 * A Source's import history, where the Instance Administrator sees what each of its imports did,
 * and starts one. It shows the imports as they were when it loaded: it doesn't reload by itself.
 */
export const Route = createFileRoute('/_shell/_admin/admin/sources/$id/imports')({
  loader: async ({context, params}) => {
    const sources = await context.queryClient.ensureQueryData(sourcesQuery);
    if (!sources.some(source => source.id === params.id)) {
      throw notFound();
    }
    await context.queryClient.ensureQueryData(mediaImportsQuery(params.id));
  },
  component: ImportHistory,
});

function ImportHistory() {
  const {t} = useTranslation('web');
  const {id} = Route.useParams();
  const {data: sources} = useSuspenseQuery(sourcesQuery);
  const {data: mediaImports} = useSuspenseQuery(mediaImportsQuery(id));
  const typeTexts = useSourceTypeTexts();
  const [isImporting, setIsImporting] = useState(false);

  // Gone when it was deleted since the page loaded
  const source = sources.find(each => each.id === id);
  if (source === undefined) {
    throw notFound();
  }
  const place = isServarrSource(source) ? source.url : source.path;
  const importButton = importsFiles(source) && (
    <Button
      onClick={() => {
        setIsImporting(true);
      }}
    >
      <PlayIcon />
      {t($ => $.web.mediaImports.import)}
    </Button>
  );

  return (
    <Page title={t($ => $.web.mediaImports.history)} actions={importButton}>
      <div className="flex flex-col items-start gap-2">
        <Link to="/admin/sources" className={buttonVariants({variant: 'ghost', size: 'sm'})}>
          <ArrowLeftIcon />
          {t($ => $.web.sources.title)}
        </Link>
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="secondary">{typeTexts[source.type].name}</Badge>
          <span className="font-mono text-sm break-all">{place}</span>
        </div>
      </div>
      {mediaImports.length === 0 ? (
        <Empty className="border p-6">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <HistoryIcon />
            </EmptyMedia>
            <EmptyTitle>{t($ => $.web.mediaImports.empty.title)}</EmptyTitle>
            <EmptyDescription>{t($ => $.web.mediaImports.empty.description)}</EmptyDescription>
          </EmptyHeader>
        </Empty>
      ) : (
        <MediaImportsTable source={source} mediaImports={mediaImports} />
      )}
      {importsFiles(source) && (
        <ImportDialog
          source={source}
          place={place}
          open={isImporting}
          onOpenChange={setIsImporting}
        />
      )}
    </Page>
  );
}
