/**
 * Media Imports: the runs that bring a Source's Media Files into WatchClub, which the Instance
 * Administrator starts, and looks through in each Source's history. The hourly schedule starts one
 * for each Source too.
 */
import {mutationOptions, queryOptions} from '@tanstack/react-query';
import * as api from '@watchclub/api';

/** The choices of the files an import handles, in the order screens list them. */
export const FILES_TO_IMPORT: readonly api.FilesToImport[] = ['new', 'new_and_unmatched', 'all'];

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

/** Returns whether the import is still going: waiting for its turn, or running. */
export function isInProgress(mediaImport: api.MediaImport): boolean {
  return mediaImport.state === 'waiting' || mediaImport.state === 'running';
}

/** Returns the number of files the import handled so far, whatever it found. */
export function handledFileCount(mediaImport: api.MediaImport): number {
  return (
    mediaImport.matched_file_count +
    mediaImport.unmatched_file_count +
    mediaImport.failed_file_count
  );
}

/** Returns how long the import took, in whole seconds, or null while it's going. */
export function durationSeconds(mediaImport: api.MediaImport): number | null {
  if (mediaImport.finished_at === null) {
    return null;
  }
  const milliseconds = Date.parse(mediaImport.finished_at) - Date.parse(mediaImport.started_at);
  return Math.round(milliseconds / 1000);
}
