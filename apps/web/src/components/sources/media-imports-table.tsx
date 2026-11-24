import type {MediaImport, MediaImportState, MediaImportTrigger, Source} from '@watchclub/api';
import {formatRelativeTime} from '@watchclub/core/l10n';
import {
  durationSeconds,
  type FileOutcome,
  summarizeFiles,
} from '@watchclub/core/sources/media-imports';
import * as icons from 'lucide-react';
import {useTranslation} from 'react-i18next';
import {
  useFilesToImportTexts,
  useMediaImportFailureMessage,
  useMediaImportStateNames,
  useMediaImportTriggerNames,
} from '@/components/sources/texts';
import {Badge} from '@/components/ui/badge';
import {Progress} from '@/components/ui/progress';
import {Table, TableBody, TableCell, TableHead, TableHeader, TableRow} from '@/components/ui/table';

/** The look of each state of an import: its icon, and its badge's variant. */
const STATE_STYLES: Record<
  MediaImportState,
  {icon: icons.LucideIcon; variant: 'secondary' | 'outline' | 'destructive'}
> = {
  waiting: {icon: icons.ClockIcon, variant: 'outline'},
  running: {icon: icons.LoaderCircleIcon, variant: 'outline'},
  completed: {icon: icons.CircleCheckIcon, variant: 'secondary'},
  failed: {icon: icons.CircleAlertIcon, variant: 'destructive'},
};

/** The icon of what started an import. */
const TRIGGER_ICONS: Record<MediaImportTrigger, icons.LucideIcon> = {
  manual: icons.MousePointerClickIcon,
  scheduled: icons.CalendarClockIcon,
};

/**
 * A Source's imports, the latest first: their state, the files they handled and what they found,
 * when they started and how long they took, and what started them.
 */
export function MediaImportsTable({
  source,
  mediaImports,
}: {
  source: Source;
  mediaImports: MediaImport[];
}) {
  const {t} = useTranslation('web');
  return (
    // A container, so that narrow pages leave out the duration and what started each import
    <div className="@container">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>{t($ => $.web.mediaImports.table.status)}</TableHead>
            <TableHead className="w-full">{t($ => $.web.mediaImports.table.files)}</TableHead>
            <TableHead>{t($ => $.web.mediaImports.table.started)}</TableHead>
            <TableHead className="hidden @xl:table-cell">
              {t($ => $.web.mediaImports.table.duration)}
            </TableHead>
            <TableHead className="hidden @xl:table-cell">
              {t($ => $.web.mediaImports.table.trigger)}
            </TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {mediaImports.map(mediaImport => (
            <MediaImportRow key={mediaImport.id} source={source} mediaImport={mediaImport} />
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

/** An import of the Source, as a row of its history. */
function MediaImportRow({source, mediaImport}: {source: Source; mediaImport: MediaImport}) {
  const {i18n} = useTranslation('web');
  const stateNames = useMediaImportStateNames();
  const triggerNames = useMediaImportTriggerNames();
  const failureMessage = useMediaImportFailureMessage();
  const {icon: StateIcon, variant} = STATE_STYLES[mediaImport.state];
  const TriggerIcon = TRIGGER_ICONS[mediaImport.trigger];
  const duration = durationSeconds(mediaImport);

  return (
    <TableRow>
      <TableCell className="align-top">
        <div className="flex flex-col items-start gap-1">
          <Badge variant={variant}>
            <StateIcon className={mediaImport.state === 'running' ? 'animate-spin' : undefined} />
            {stateNames[mediaImport.state]}
          </Badge>
          {mediaImport.failure !== null && (
            <p className="max-w-56 text-xs whitespace-normal text-muted-foreground">
              {failureMessage(mediaImport.failure, source.type)}
            </p>
          )}
        </div>
      </TableCell>
      <TableCell className="align-top">
        <ImportedFiles mediaImport={mediaImport} />
      </TableCell>
      <TableCell className="align-top whitespace-nowrap text-muted-foreground">
        {formatRelativeTime(mediaImport.started_at, i18n.language)}
      </TableCell>
      <TableCell className="hidden align-top text-muted-foreground tabular-nums @xl:table-cell">
        {duration === null ? '—' : formatDuration(duration, i18n.language)}
      </TableCell>
      <TableCell className="hidden align-top @xl:table-cell">
        <Badge variant="outline">
          <TriggerIcon />
          {triggerNames[mediaImport.trigger]}
        </Badge>
      </TableCell>
    </TableRow>
  );
}

/** The look of the number of files with each outcome. */
const OUTCOME_CLASS_NAMES: Record<FileOutcome, string> = {
  matched: '',
  unmatched: '',
  failed: 'text-destructive',
  removed: 'text-muted-foreground',
};

/**
 * The files an import handles, and how far it got: a progress bar while it runs, and what became of
 * its files.
 */
function ImportedFiles({mediaImport}: {mediaImport: MediaImport}) {
  const {t} = useTranslation('web');
  const choiceTexts = useFilesToImportTexts();
  const {isListing, isEmpty, progress, outcomes} = summarizeFiles(mediaImport);

  function outcomeText(outcome: FileOutcome, count: number): string {
    switch (outcome) {
      case 'matched':
        return t($ => $.web.mediaImports.matched, {count});
      case 'unmatched':
        return t($ => $.web.mediaImports.unmatched, {count});
      case 'failed':
        return t($ => $.web.mediaImports.failed, {count});
      case 'removed':
        return t($ => $.web.mediaImports.removed, {count});
    }
  }

  return (
    <div className="flex flex-col items-start gap-2">
      <Badge variant="secondary">{choiceTexts[mediaImport.files_to_import].shortName}</Badge>
      {isListing && (
        <p className="text-muted-foreground">{t($ => $.web.mediaImports.findingFiles)}</p>
      )}
      {isEmpty && <p className="text-muted-foreground">{t($ => $.web.mediaImports.noFiles)}</p>}
      {progress !== null && (
        <Progress value={(100 * progress.handled) / progress.total} className="w-40">
          <span className="text-muted-foreground tabular-nums">
            {t($ => $.web.mediaImports.progress, {
              handled: progress.handled,
              count: progress.total,
            })}
          </span>
        </Progress>
      )}
      {outcomes.length > 0 && (
        <ul className="flex flex-col tabular-nums">
          {outcomes.map(({outcome, count}) => (
            <li key={outcome} className={OUTCOME_CLASS_NAMES[outcome]}>
              {outcomeText(outcome, count)}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/** Returns a duration in the language, short, such as "1m 5s". */
function formatDuration(seconds: number, language: string): string {
  const minutes = Math.floor(seconds / 60);
  return new Intl.DurationFormat(language, {style: 'narrow'}).format({
    minutes,
    seconds: seconds - minutes * 60,
  });
}
