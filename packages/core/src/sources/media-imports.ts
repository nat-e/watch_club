/**
 * Media Imports: the runs that bring a Source's Media Files into WatchClub, which the Instance
 * Administrator starts, and looks through in each Source's history. The hourly schedule starts one
 * for each Source too.
 */
import {mutationOptions, queryOptions} from '@tanstack/react-query';
import * as api from '@watchclub/api';

/** The choices of the files an import handles, in the order screens list them. */
export const FILES_TO_IMPORT: readonly api.FilesToImport[] = ['new', 'new_and_unmatched', 'all'];

/** The outcomes of files, in the order screens list them. */
const FILE_OUTCOMES: readonly FileOutcome[] = ['matched', 'unmatched', 'failed', 'removed'];

/** Returns whether the Source imports its files: only Radarr Sources do yet. */
export function importsFiles(source: api.Source): boolean {
  return source.type === 'radarr';
}

/** Returns the query of the Source's imports, the latest first. */
export function mediaImportsQuery(sourceId: api.SourceId) {
  return queryOptions(api.listMediaImportsOptions({path: {id: sourceId}}));
}

/** An import to start: the Source's files it handles. */
interface MediaImportStart {
  sourceId: api.SourceId;
  filesToImport: api.FilesToImport;
}

/** The mutation that starts an import of a Source's files, then refreshes its imports. */
export const startMediaImportMutation = mutationOptions({
  mutationFn: async ({sourceId, filesToImport}: MediaImportStart, {client: queryClient}) => {
    const {data} = await api.startMediaImport({
      path: {id: sourceId},
      // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
      body: {files_to_import: filesToImport},
      throwOnError: true,
    });
    await queryClient.invalidateQueries({queryKey: mediaImportsQuery(sourceId).queryKey});
    return data;
  },
});

/** What became of some of an import's files. */
export type FileOutcome = 'matched' | 'unmatched' | 'failed' | 'removed';

/** What an import did with its Source's files so far, as screens show it. */
export interface ImportedFilesSummary {
  /** Whether its Source is still listing its files */
  isListing: boolean;
  /** Whether it found no file to handle or to remove */
  isEmpty: boolean;
  /** The files it handled out of those it handles, while it runs; null otherwise */
  progress: {handled: number; total: number} | null;
  /** The number of files with each outcome, leaving out those with none */
  outcomes: Array<{outcome: FileOutcome; count: number}>;
}

/** Returns what the import did with its Source's files so far. */
export function summarizeFiles(mediaImport: api.MediaImport): ImportedFilesSummary {
  const isInProgress = mediaImport.state === 'waiting' || mediaImport.state === 'running';
  const total = mediaImport.file_count;
  const counts: Record<FileOutcome, number> = {
    matched: mediaImport.matched_file_count,
    unmatched: mediaImport.unmatched_file_count,
    failed: mediaImport.failed_file_count,
    removed: mediaImport.removed_file_count,
  };
  const outcomes = FILE_OUTCOMES.map(outcome => ({outcome, count: counts[outcome]})).filter(
    ({count}) => count > 0,
  );
  const handled = counts.matched + counts.unmatched + counts.failed;

  return {
    isListing: isInProgress && total === null,
    isEmpty: total === 0 && outcomes.length === 0,
    progress: isInProgress && total !== null && total > 0 ? {handled, total} : null,
    outcomes,
  };
}

/** Returns how long the import took, in whole seconds, or null while it's going. */
export function durationSeconds(mediaImport: api.MediaImport): number | null {
  if (mediaImport.finished_at === null) {
    return null;
  }
  const milliseconds = Date.parse(mediaImport.finished_at) - Date.parse(mediaImport.started_at);
  return Math.round(milliseconds / 1000);
}
