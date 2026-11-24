import type {MediaImport, Source} from '@watchclub/api';
import {describe, expect, it} from 'vitest';
import {
  durationSeconds,
  handledFileCount,
  importsFiles,
  isInProgress,
} from '../../src/sources/media-imports';

/** A completed import of 5 files, which took 75 seconds. */
const COMPLETED: MediaImport = {
  id: '01a1f26b-170d-75e6-b05d-1b3ceacf37a0',
  trigger: 'manual',
  // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
  files_to_import: 'all',
  state: 'completed',
  failure: null,
  file_count: 5,
  matched_file_count: 3,
  unmatched_file_count: 1,
  failed_file_count: 1,
  removed_file_count: 2,
  started_at: '2026-11-20T10:00:00Z',
  finished_at: '2026-11-20T10:01:15Z',
  // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
};

describe('importsFiles', () => {
  it('is true for Radarr Sources only', () => {
    const radarr: Source = {
      type: 'radarr',
      id: '01a1f26b-170d-75e6-b05d-1b3ceacf37a1',
      // biome-ignore-start lint/style/useNamingConvention: the API's fields are snake_case
      media_type: 'movie',
      url: 'http://radarr:7878/',
      quality_profile: {id: 4, name: 'HD-1080p'},
      root_folder_path: '/movies',
      local_root_folder_path: null,
      // biome-ignore-end lint/style/useNamingConvention: the API's fields are snake_case
    };
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    const sonarr: Source = {...radarr, type: 'sonarr', media_type: 'tv_show_episode'};

    expect(importsFiles(radarr)).toBe(true);
    expect(importsFiles(sonarr)).toBe(false);
  });
});

describe('isInProgress', () => {
  it('is true while the import waits or runs', () => {
    expect(isInProgress({...COMPLETED, state: 'waiting'})).toBe(true);
    expect(isInProgress({...COMPLETED, state: 'running'})).toBe(true);
    expect(isInProgress(COMPLETED)).toBe(false);
    expect(isInProgress({...COMPLETED, state: 'failed', failure: 'interrupted'})).toBe(false);
  });
});

describe('handledFileCount', () => {
  it('counts the matched, Unmatched and failed files, not the removed ones', () => {
    expect(handledFileCount(COMPLETED)).toBe(5);
  });
});

describe('durationSeconds', () => {
  it('is the time from start to finish', () => {
    expect(durationSeconds(COMPLETED)).toBe(75);
  });

  it('is null while the import is going', () => {
    // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
    expect(durationSeconds({...COMPLETED, state: 'running', finished_at: null})).toBeNull();
  });
});
