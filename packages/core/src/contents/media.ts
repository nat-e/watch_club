/**
 * Media: what Users play inside a Content, such as each of a TV Show's Episodes, as both apps show
 * them.
 */
import {queryOptions} from '@tanstack/react-query';
import {listMediaOfContentOptions, type Media} from '@watchclub/api';
import {useTranslation} from 'react-i18next';
import {longDate, useFormatRuntime} from './content';

/**
 * Returns the query of a Content's Media in order, such as a TV Show's Episodes by season and
 * number, with their texts in the User's Locale.
 */
export function mediaQuery(contentId: string) {
  // biome-ignore lint/style/useNamingConvention: the API's path parameters are snake_case
  return queryOptions(listMediaOfContentOptions({path: {content_id: contentId}}));
}

/** The Media of one group, such as a TV Show's season. */
export interface MediaGroup {
  /** Its number, such as a season's */
  number: number;
  media: Media[];
}

/**
 * Returns the Media by group, in the order the API lists them, such as a TV Show's Episodes by
 * season. Media without a group, such as a Movie's, are left out.
 */
export function groupMedia(media: readonly Media[]): MediaGroup[] {
  const groups: MediaGroup[] = [];
  for (const item of media) {
    if (item.group_number === null) {
      continue;
    }
    const lastGroup = groups.at(-1);
    if (lastGroup?.number === item.group_number) {
      lastGroup.media.push(item);
    } else {
      groups.push({number: item.group_number, media: [item]});
    }
  }
  return groups;
}

/** The facts a TV Show Episode's row shows, as the app's language writes them. */
export interface EpisodeFacts {
  /** Its season and number, such as "S01E02" */
  code: string;
  runtime: string | null;
  /** When it comes out, while it isn't out yet, such as "Out on June 3, 2026" */
  releaseNote: string | null;
  /** Whether it's out: it has a release date, today or before */
  isOut: boolean;
}

/** Returns the function that gives the facts of a TV Show Episode's row. */
export function useEpisodeFacts(): (episode: Media) => EpisodeFacts {
  const {t, i18n} = useTranslation('core');
  const formatRuntime = useFormatRuntime();
  const today = isoDay(new Date());
  return episode => {
    const isOut = episode.release_date !== null && episode.release_date <= today;
    let releaseNote: string | null = null;
    if (episode.release_date === null) {
      releaseNote = t($ => $.core.episodes.notOutYet);
    } else if (!isOut) {
      releaseNote = t($ => $.core.episodes.outOn, {
        date: longDate(episode.release_date, i18n.language),
      });
    }
    return {
      code: episodeCode(episode),
      runtime: episode.runtime_seconds === null ? null : formatRuntime(episode.runtime_seconds),
      releaseNote,
      isOut,
    };
  };
}

/** Returns a TV Show Episode's season and number, such as "S01E02". */
export function episodeCode(episode: Media): string {
  const twoDigits = (number: number | null) => String(number ?? 0).padStart(2, '0');
  return `S${twoDigits(episode.group_number)}E${twoDigits(episode.number)}`;
}

/** Returns a day as the API writes it, such as `2026-06-03`, in the device's time zone. */
function isoDay(date: Date): string {
  const twoDigits = (number: number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())}`;
}
