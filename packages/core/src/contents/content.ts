/**
 * Content: the Movies, TV Shows, Sports Events and Books Users watch, read and talk about, as both
 * apps show them.
 */
import {queryOptions} from '@tanstack/react-query';
import {
  type Content,
  type ContentType,
  type Credit,
  type ExternalContentId,
  type Genre,
  getContentByExternalIdOptions,
} from '@watchclub/api';
import {useTranslation} from 'react-i18next';

/** The number of characters past which a Content's page shortens its overview, with More */
export const LONG_OVERVIEW_LENGTH = 300;

/**
 * Returns the query of a Content, with its texts in the User's Locale. The first time someone opens
 * it, the server saves it from its Metadata Provider first, which takes a moment.
 */
export function contentQuery({content_type, external_id}: ExternalContentId) {
  // biome-ignore lint/style/useNamingConvention: the API's path parameters are snake_case
  return queryOptions(getContentByExternalIdOptions({path: {content_type, external_id}}));
}

/** Returns the name of each type of Content in the app's language, such as "Movie". */
export function useContentTypeNames(): Record<ContentType, string> {
  const {t} = useTranslation('core');
  return {
    movie: t($ => $.core.contentTypes.movie),
    // biome-ignore lint/style/useNamingConvention: the API's Content Types are snake_case
    tv_show: t($ => $.core.contentTypes.tvShow),
    // biome-ignore lint/style/useNamingConvention: the API's Content Types are snake_case
    sports_event: t($ => $.core.contentTypes.sportsEvent),
    book: t($ => $.core.contentTypes.book),
  };
}

/**
 * The facts a Content's page shows under its title, as the app's language writes them, or null
 * when the Content doesn't have them.
 */
export interface ContentFacts {
  /** Its original language's name, and the flag of the country that speaks it most */
  originalLanguage: OriginalLanguage | null;
  /** The year it came out, or the day a Sports Event takes place */
  date: string | null;
  contentType: string;
  /** A Movie's runtime, or a TV Show's number of seasons */
  length: string | null;
  /** Its rating out of 10, to one decimal, such as "7.9" */
  rating: string | null;
  /** The page of its rating at its Metadata Provider */
  ratingUrl: string | null;
}

/** A Content's original language. */
export interface OriginalLanguage {
  /** Its name in the app's language, such as "French" */
  name: string;
  /** The emoji flag of the country that speaks it most, such as 🇫🇷 */
  flag: string;
}

/** Returns the facts a Content's page shows under its title. */
export function useContentFacts(content: Content): ContentFacts {
  const {t, i18n} = useTranslation('core');
  const contentTypeNames = useContentTypeNames();
  const formatRuntime = useFormatRuntime();
  const language = i18n.language;

  let length: string | null = null;
  if (content.content_type === 'tv_show' && content.media_group_count > 0) {
    length = t($ => $.core.contents.seasonCount, {count: content.media_group_count});
  } else if (content.runtime_seconds !== null) {
    length = formatRuntime(content.runtime_seconds);
  }

  return {
    originalLanguage:
      content.original_language === null
        ? null
        : originalLanguage(content.original_language, language),
    date:
      content.release_date === null
        ? null
        : releaseText(content.content_type, content.release_date, language),
    contentType: contentTypeNames[content.content_type],
    length,
    rating: content.rating === null ? null : formatRating(content.rating, language),
    ratingUrl: tmdbUrl(content),
  };
}

/** Returns the name of each genre in the app's language, such as "Science fiction". */
export function useGenreNames(): Record<Genre, string> {
  const {t} = useTranslation('core');
  return {
    action: t($ => $.core.genres.action),
    adventure: t($ => $.core.genres.adventure),
    animation: t($ => $.core.genres.animation),
    comedy: t($ => $.core.genres.comedy),
    crime: t($ => $.core.genres.crime),
    documentary: t($ => $.core.genres.documentary),
    drama: t($ => $.core.genres.drama),
    family: t($ => $.core.genres.family),
    fantasy: t($ => $.core.genres.fantasy),
    history: t($ => $.core.genres.history),
    horror: t($ => $.core.genres.horror),
    kids: t($ => $.core.genres.kids),
    music: t($ => $.core.genres.music),
    mystery: t($ => $.core.genres.mystery),
    news: t($ => $.core.genres.news),
    politics: t($ => $.core.genres.politics),
    reality: t($ => $.core.genres.reality),
    romance: t($ => $.core.genres.romance),
    // biome-ignore-start lint/style/useNamingConvention: the API's genres are snake_case
    science_fiction: t($ => $.core.genres.scienceFiction),
    soap: t($ => $.core.genres.soap),
    talk: t($ => $.core.genres.talk),
    thriller: t($ => $.core.genres.thriller),
    tv_movie: t($ => $.core.genres.tvMovie),
    // biome-ignore-end lint/style/useNamingConvention: the API's genres are snake_case
    war: t($ => $.core.genres.war),
    western: t($ => $.core.genres.western),
  };
}

/**
 * Returns the function that gives the line under a credited person's name: the character an actor
 * plays, or Director.
 */
export function useCreditRole(): (credit: Credit) => string | null {
  const {t} = useTranslation('core');
  return credit => {
    switch (credit.kind) {
      case 'actor':
        return credit.character;
      case 'director':
        return t($ => $.core.contents.creditKinds.director);
      // Only the pages of Movies and TV Shows show their credits for now
      case 'author':
      case 'illustrator':
      case 'narrator':
      case 'artist':
      case 'league':
        return null;
    }
  };
}

/** Returns a person's initials, such as "AT" for Audrey Tautou, for a photo they don't have. */
export function initials(name: string): string {
  return name
    .split(' ')
    .filter(word => word !== '')
    .slice(0, 2)
    .map(word => word.slice(0, 1))
    .join('');
}

/** Returns the function that writes a runtime in seconds, such as "2 hr 2 min", in the app's language. */
export function useFormatRuntime(): (seconds: number) => string {
  const {t} = useTranslation('core');
  return seconds => {
    const totalMinutes = Math.round(seconds / 60);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours === 0) {
      return t($ => $.core.contents.runtime, {context: 'minutes', minutes});
    }
    if (minutes === 0) {
      return t($ => $.core.contents.runtime, {context: 'hours', hours});
    }
    return t($ => $.core.contents.runtime, {hours, minutes});
  };
}

/** Returns a rating out of 10 to one decimal, as `language`, such as `fr-FR`, writes it. */
export function formatRating(rating: number, language: string): string {
  return rating.toLocaleString(language, {minimumFractionDigits: 1, maximumFractionDigits: 1});
}

/** Returns a day, such as `2024-09-15`, as `language` writes it in full, such as "15 septembre 2024". */
export function longDate(day: string, language: string): string {
  return midnight(day).toLocaleDateString(language, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

/**
 * Returns the page of a Movie or a TV Show on TMDB, where its rating comes from, or null for other
 * Content.
 */
export function tmdbUrl({content_type, external_id}: ExternalContentId): string | null {
  switch (content_type) {
    case 'movie':
      return `https://www.themoviedb.org/movie/${external_id}`;
    case 'tv_show':
      return `https://www.themoviedb.org/tv/${external_id}`;
    case 'sports_event':
    case 'book':
      return null;
  }
}

/** Returns when a Content came out: the day of a Sports Event, or the year of the others. */
function releaseText(contentType: ContentType, releaseDate: string, language: string): string {
  // Only Sports Events need their day to tell them apart
  return contentType === 'sports_event'
    ? longDate(releaseDate, language)
    : String(midnight(releaseDate).getFullYear());
}

/**
 * Returns a language's name in `appLanguage` and the flag of the country that speaks it most, or
 * null for a code the platform doesn't know.
 */
function originalLanguage(code: string, appLanguage: string): OriginalLanguage | null {
  try {
    const name = new Intl.DisplayNames([appLanguage], {type: 'language'}).of(code);
    // Adds the likeliest script and country, as `fr-Latn-FR` for `fr`
    const country = new Intl.Locale(code).maximize().region;
    if (name === undefined || country === undefined) {
      return null;
    }
    return {name, flag: flagEmoji(country)};
  } catch (error) {
    // A code that isn't a language
    if (error instanceof RangeError) {
      return null;
    }
    throw error;
  }
}

/** Returns a country's flag emoji, from its ISO 3166-1 code: the regional indicators of its letters. */
function flagEmoji(country: string): string {
  const regionalIndicatorA = 0x1f1e6;
  return String.fromCodePoint(
    ...[...country.toUpperCase()].map(
      letter => regionalIndicatorA + letter.charCodeAt(0) - 'A'.charCodeAt(0),
    ),
  );
}

/** Returns midnight of a day, such as `2001-04-25`, in the device's time zone, so the day stays. */
function midnight(day: string): Date {
  return new Date(`${day}T00:00`);
}
