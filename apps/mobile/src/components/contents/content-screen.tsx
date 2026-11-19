import {Button} from '@expo/ui';
import {useQuery} from '@tanstack/react-query';
import {type Content, type ContentType, hasCode} from '@watchclub/api';
import {
  contentQuery,
  initials,
  LONG_OVERVIEW_LENGTH,
  useContentFacts,
  useCreditRole,
  useGenreNames,
} from '@watchclub/core/contents/content';
import {router, Stack, useLocalSearchParams} from 'expo-router';
import {SymbolView, type SymbolViewProps} from 'expo-symbols';
import {useState} from 'react';
import {useTranslation} from 'react-i18next';
import {ActivityIndicator, Linking, Pressable, ScrollView, Text, View} from 'react-native';
import {useCSSVariable} from 'uniwind';
import {Poster} from '@/components/contents/poster';
import {SizedImage} from '@/components/contents/sized-image';
import {Host} from '@/components/host';
import {StatusScreen} from '@/components/layouts/status-screen';
import {ScrollRow} from '@/components/scroll-row';

/**
 * The screen of the Content whose External ID is the route's `id`, with its title in the header.
 * The screens of Sports Events and Books only show their title for now.
 */
export function ContentScreen({contentType}: {contentType: ContentType}) {
  const {t} = useTranslation('core');
  const {id} = useLocalSearchParams<{id: string}>();
  // biome-ignore lint/style/useNamingConvention: the API's fields are snake_case
  const content = useQuery(contentQuery({content_type: contentType, external_id: id}));
  const messages = useMessages(contentType);

  if (hasCode(content.error, 'not_found')) {
    return <StatusScreen description={messages.notFound} actions={[]} />;
  }
  if (content.isError) {
    return (
      <StatusScreen
        description={messages.loadFailed}
        actions={[
          {
            label: t($ => $.core.controls.tryAgain),
            onPress: () => {
              void content.refetch();
            },
          },
        ]}
      />
    );
  }
  return (
    <>
      <Stack.Screen options={{title: content.data?.title ?? ''}} />
      {content.isPending && (
        <View className="flex-1 items-center justify-center">
          <ActivityIndicator accessibilityLabel={t($ => $.core.contents.loading)} />
        </View>
      )}
      {content.data &&
        (content.data.content_type === 'movie' || content.data.content_type === 'tv_show') && (
          <ContentDetails content={content.data} />
        )}
    </>
  );
}

/** A Movie's or a TV Show's header on its dimmed backdrop, then its cast. */
function ContentDetails({content}: {content: Content}) {
  const genreNames = useGenreNames();
  return (
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerClassName="pb-8">
      <View className="items-center gap-4 px-4 py-6">
        {content.backdrop && (
          <View
            className="absolute inset-0"
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
          >
            <SizedImage image={content.backdrop} style={{flex: 1}} />
            <View className="absolute inset-0 bg-background/80" />
          </View>
        )}
        <Poster image={content.poster} width={112} />
        <View className="items-center gap-1">
          <Text
            accessibilityRole="header"
            className="text-center font-heading text-3xl text-foreground"
          >
            {content.title}
          </Text>
          <Facts content={content} />
        </View>
        {content.genres.length > 0 && (
          <View className="flex-row flex-wrap justify-center gap-1">
            {content.genres.map(genre => (
              <Text
                key={genre}
                className="overflow-hidden rounded-full border border-border bg-secondary px-2 py-0.5 text-xs font-semibold text-secondary-foreground"
              >
                {genreNames[genre]}
              </Text>
            ))}
          </View>
        )}
        {content.overview && <Overview text={content.overview} />}
        <Actions content={content} />
      </View>
      <Cast content={content} />
    </ScrollView>
  );
}

/**
 * "🇫🇷 2001 · Movie · 2 hr 2 min · ★ 7.9": the original language's flag next to the year, then the
 * rating, which opens the Content on TMDB.
 */
function Facts({content}: {content: Content}) {
  const {t} = useTranslation('core');
  const facts = useContentFacts(content);
  const languageLabel =
    facts.originalLanguage &&
    t($ => $.core.contents.originalLanguage, {language: facts.originalLanguage.name});
  const firstFact = [facts.originalLanguage?.flag, facts.date]
    .filter(text => Boolean(text))
    .join(' ');
  const texts = [firstFact, facts.contentType, facts.length].filter(text => Boolean(text));
  // The flag means nothing to screen readers: they read the language's name instead
  const spokenTexts = [languageLabel, facts.date, facts.contentType, facts.length].filter(text =>
    Boolean(text),
  );
  const ratingUrl = facts.ratingUrl;

  return (
    <View className="flex-row flex-wrap items-center justify-center gap-x-2">
      <Text
        accessibilityLabel={spokenTexts.join(', ')}
        className="text-center text-sm text-muted-foreground"
      >
        {texts.join(' · ')}
      </Text>
      {facts.rating && (
        <Pressable
          accessibilityRole="link"
          accessibilityHint={t($ => $.core.contents.seeOnTmdb)}
          disabled={ratingUrl === null}
          onPress={() => {
            if (ratingUrl !== null) {
              void Linking.openURL(ratingUrl);
            }
          }}
          className="rounded-sm focus:bg-accent"
        >
          {/* i18next-instrument-ignore: a separator and a star, the same in every language */}
          <Text className="text-sm font-semibold text-foreground">
            <Text className="font-normal text-muted-foreground">· </Text>
            <Text className="text-warning">★</Text> {facts.rating}
          </Text>
        </Pressable>
      )}
    </View>
  );
}

/** The overview: a long one shortened to a few lines, with More to read it whole. */
function Overview({text}: {text: string}) {
  const {t} = useTranslation('core');
  const [isExpanded, setIsExpanded] = useState(false);
  const isLong = text.length > LONG_OVERVIEW_LENGTH;
  return (
    <View className="items-center gap-1">
      <Text
        numberOfLines={isLong && !isExpanded ? 3 : undefined}
        className="text-center text-base text-muted-foreground"
      >
        {text}
      </Text>
      {isLong && (
        <Pressable
          accessibilityRole="button"
          accessibilityState={{expanded: isExpanded}}
          onPress={() => {
            setIsExpanded(!isExpanded);
          }}
          className="rounded-md px-3 py-1.5 active:bg-pressed focus:bg-accent"
        >
          <Text className="text-sm font-semibold text-foreground">
            {isExpanded ? t($ => $.core.contents.less) : t($ => $.core.contents.more)}
          </Text>
        </Pressable>
      )}
    </View>
  );
}

/**
 * Request first, then the quieter Episodes of a TV Show, Watch trailer and Mark as watched. Request
 * and Mark as watched wait for their features.
 */
function Actions({content}: {content: Content}) {
  const {t} = useTranslation('core');
  const trailerUrl = content.trailer_url;
  return (
    <View className="w-full items-center gap-4">
      <Host matchContents={{vertical: true}} style={{width: '100%', maxWidth: 384}}>
        <Button
          variant="filled"
          label={t($ => $.core.contents.request)}
          disabled
          onPress={() => undefined}
        />
      </Host>
      <View className="flex-row justify-center gap-4">
        {content.content_type === 'tv_show' && content.media_group_count > 0 && (
          <RoundAction
            label={t($ => $.core.contents.episodes)}
            symbol={{ios: 'list.bullet.rectangle', android: 'video_library'}}
            onPress={() => {
              router.push({
                pathname: '/episodes/[contentId]',
                params: {contentId: content.id, title: content.title},
              });
            }}
          />
        )}
        {trailerUrl && (
          <RoundAction
            label={t($ => $.core.contents.watchTrailer)}
            symbol={{ios: 'play.circle', android: 'play_circle'}}
            onPress={() => {
              void Linking.openURL(trailerUrl);
            }}
          />
        )}
        <RoundAction
          label={t($ => $.core.contents.markAsWatched)}
          symbol={{ios: 'circle', android: 'radio_button_unchecked'}}
          disabled
        />
      </View>
    </View>
  );
}

/** A quiet action beside the main one: its symbol in a circle, with its label under it. */
function RoundAction({
  label,
  symbol,
  onPress,
  disabled = false,
}: {
  label: string;
  /** Its symbol on each platform: SF Symbols on iOS, Material Symbols on Android */
  symbol: SymbolViewProps['name'];
  onPress?: () => void;
  disabled?: boolean;
}) {
  const foreground = useCSSVariable('--color-foreground');
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      disabled={disabled}
      onPress={onPress}
      className={`w-20 items-center gap-1 rounded-md ${disabled ? 'opacity-50' : ''}`}
    >
      {/* The border shows which one a TV's remote is on */}
      <View className="size-12 items-center justify-center rounded-full border border-border bg-secondary focus:border-ring">
        <SymbolView name={symbol} tintColor={String(foreground)} size={22} />
      </View>
      <Text className="text-center text-xs text-muted-foreground">{label}</Text>
    </Pressable>
  );
}

/** Who directed the Content, then who's in it, as round photos in a row that scrolls sideways. */
function Cast({content}: {content: Content}) {
  const {t} = useTranslation('core');
  const creditRole = useCreditRole();
  if (content.credits.length === 0) {
    return null;
  }

  return (
    <View className="gap-3 pt-4">
      <Text accessibilityRole="header" className="px-4 font-heading text-xl text-foreground">
        {t($ => $.core.contents.cast)}
      </Text>
      <ScrollRow contentContainerClassName="gap-4 px-4">
        {content.credits.map((credit, index) => {
          const role = creditRole(credit);
          return (
            // Credits keep their order, and have no ID
            // biome-ignore lint/suspicious/noArrayIndexKey: see above
            <View key={index} className="w-24 items-center gap-2" accessible>
              <View className="size-20 items-center justify-center overflow-hidden rounded-full bg-secondary">
                {credit.photo ? (
                  <SizedImage image={credit.photo} style={{width: 80, height: 80}} />
                ) : (
                  <Text className="text-sm font-semibold text-muted-foreground">
                    {initials(credit.name)}
                  </Text>
                )}
              </View>
              <View className="w-full items-center">
                <Text
                  numberOfLines={2}
                  className="text-center text-sm font-semibold text-foreground"
                >
                  {credit.name}
                </Text>
                {role && (
                  <Text numberOfLines={1} className="text-xs text-muted-foreground">
                    {role}
                  </Text>
                )}
              </View>
            </View>
          );
        })}
      </ScrollRow>
    </View>
  );
}

/** Returns the screen's messages, whose words depend on the type of Content, such as its gender. */
function useMessages(contentType: ContentType): {notFound: string; loadFailed: string} {
  const {t} = useTranslation('core');
  switch (contentType) {
    case 'movie':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'movie'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'movie'}),
      };
    case 'tv_show':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'tvShow'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'tvShow'}),
      };
    case 'sports_event':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'sportsEvent'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'sportsEvent'}),
      };
    case 'book':
      return {
        notFound: t($ => $.core.contents.notFound, {context: 'book'}),
        loadFailed: t($ => $.core.contents.loadFailed, {context: 'book'}),
      };
  }
}
