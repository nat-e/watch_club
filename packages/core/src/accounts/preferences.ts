/**
 * User Preferences: the User's choices, such as their Locale and the audio and subtitles videos
 * start with.
 */
import {hashKey, mutationOptions, type Query} from '@tanstack/react-query';
import {
  type AudioLanguage,
  type TrackLanguage,
  type UserId,
  type UserPreferences,
  updatePreferences,
} from '@watchclub/api';
import {useTranslation} from 'react-i18next';
import {currentUserQuery, updateCurrentUser} from './current-user';

/** Changes to some of a User's Preferences. */
interface PreferenceChanges {
  /** The User who made them */
  user: UserId;
  /** The new values, which leave the others as they are */
  changes: Partial<UserPreferences>;
}

/**
 * The mutation that changes some of the current User's Preferences and keeps the others, then makes
 * the app follow them, such as by switching to their new Locale. Fails once another User signed in.
 */
export const savePreferencesMutation = mutationOptions({
  mutationFn: async ({user, changes}: PreferenceChanges, {client: queryClient}) => {
    const current = queryClient.getQueryData(currentUserQuery.queryKey);
    // The User may have signed out while an earlier save ran, so the session is someone else's
    if (current?.id !== user) {
      throw new Error('the User who changed these preferences signed out');
    }
    const {data: saved} = await updatePreferences({
      body: {...current.preferences, ...changes},
      throwOnError: true,
    });
    await updateCurrentUser(queryClient, saved);
    if (saved.preferences.locale !== current.preferences.locale) {
      // The API answers in the User's language, so the answers shown so far are in the old one
      const currentUserHash = hashKey(currentUserQuery.queryKey);
      const others = {predicate: (query: Query) => query.queryHash !== currentUserHash};
      // The screens' queries are cancelled first, as one whose first answer is on its way would
      // keep it. A page that is loading keeps its answer, rather than failing to open
      await queryClient.cancelQueries({...others, type: 'active'});
      void queryClient.invalidateQueries(others);
    }
    return saved;
  },
  // One at a time, so that each save starts from the preferences the one before saved, rather than
  // undoing its changes
  scope: {id: 'savePreferences'},
});

/** A value a User can choose, with its name in the app's language. */
interface PreferenceOption<T> {
  value: T;
  label: string;
}

/** The values a User can choose for the audio and subtitles videos start with. */
interface TrackLanguageOptions {
  /** The original language, then the Track Languages, for the Preferred Audio Language */
  audio: Array<PreferenceOption<AudioLanguage>>;
  /** No subtitles, then the Track Languages, for the Preferred Subtitle Language */
  subtitles: Array<PreferenceOption<TrackLanguage | null>>;
  /** The Track Languages, for the Languages Without Subtitles */
  languages: Array<PreferenceOption<TrackLanguage>>;
}

/**
 * Returns the values a User can choose for their audio and subtitles, named in the app's language,
 * with the Track Languages sorted by name.
 */
export function useTrackLanguageOptions(): TrackLanguageOptions {
  const {t, i18n} = useTranslation('core');
  const names: Record<TrackLanguage, string> = {
    en: t($ => $.core.trackLanguages.en),
    fr: t($ => $.core.trackLanguages.fr),
  };
  const languages = Object.entries(names)
    // biome-ignore lint/nursery/noUnsafeTypeAssertion: the keys of a Record<TrackLanguage, …> are Track Languages
    .map(([value, label]) => ({value: value as TrackLanguage, label}))
    .sort((a, b) => a.label.localeCompare(b.label, i18n.language));
  return {
    audio: [{value: 'original', label: t($ => $.core.settings.originalLanguage)}, ...languages],
    subtitles: [{value: null, label: t($ => $.core.settings.subtitlesOff)}, ...languages],
    languages,
  };
}

/** Returns the name of the option with this value. */
export function labelOf<T>(options: ReadonlyArray<PreferenceOption<T>>, value: T): string {
  const option = options.find(each => each.value === value);
  if (!option) {
    throw new Error(`no option has the value ${String(value)}`);
  }
  return option.label;
}
