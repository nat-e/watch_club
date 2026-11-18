import {Autocomplete} from '@base-ui/react/autocomplete';
import {Link, useMatch, useNavigate} from '@tanstack/react-router';
import type {SearchResult} from '@watchclub/api';
import {useSearch, useTypedQuery} from '@watchclub/core/contents/search';
import {ArrowLeftIcon, SearchIcon} from 'lucide-react';
import {useRef, useState} from 'react';
import {useTranslation} from 'react-i18next';
import {contentLink} from '@/components/contents/content-page';
import {
  InLibraryFilter,
  SearchResultSummary,
  SearchStatus,
} from '@/components/contents/search-results';
import {
  InputGroup,
  InputGroupAddon,
  InputGroupButton,
  InputGroupInput,
} from '@/components/ui/input-group';
import {Kbd} from '@/components/ui/kbd';
import {useIsMobile} from '@/hooks/use-mobile';

/** The number of results the drop-down shows at most */
const PREVIEW_SIZE = 6;

/** The last option of the drop-down, which opens the search page */
const SEE_ALL = 'seeAll';

type Option = SearchResult | typeof SEE_ALL;

/**
 * The search field of a page's bar. While the User types, a drop-down shows the first results, and
 * Enter opens the search page with all of them. Up and Down move through the results. On the search
 * page, the field shows the page's query.
 *
 * On phones, the drop-down fills the screen below the bar, and the field's search icon becomes a
 * back arrow, which closes it.
 */
export function SearchField() {
  const {t} = useTranslation(['web', 'core']);
  const navigate = useNavigate();
  const isMobile = useIsMobile();
  const searchPage = useMatch({from: '/_shell/search', shouldThrow: false});
  const pageQuery = searchPage?.search.query ?? '';
  const [text, setText] = useState(pageQuery);
  // The field follows the search page's query when its URL changes, and keeps what the User types
  // in between
  const [shownPageQuery, setShownPageQuery] = useState(pageQuery);
  if (pageQuery !== shownPageQuery) {
    setShownPageQuery(pageQuery);
    setText(pageQuery);
  }
  const [open, setOpen] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const query = useTypedQuery(text);
  const search = useSearch(query);
  const preview = search.results.slice(0, PREVIEW_SIZE);
  const options: Option[] = preview.length > 0 ? [...preview, SEE_ALL] : [];

  function openSearchPage() {
    const typed = text.trim();
    if (typed === '') {
      return;
    }
    setOpen(false);
    void navigate({to: '/search', search: {query: typed}});
  }

  return (
    <Autocomplete.Root
      items={options}
      filter={null}
      value={text}
      onValueChange={(value, details) => {
        // Picking a result opens its page, and leaves the query as the User typed it
        if (details.reason !== 'item-press') {
          setText(value);
        }
      }}
      itemToStringValue={(option: Option) => (option === SEE_ALL ? text : option.title)}
      open={open}
      onOpenChange={setOpen}
      openOnInputClick
      // Keeps the page behind the full screen still, and out of reach
      modal={isMobile}
    >
      <search className="min-w-0 flex-1 md:flex-none">
        <form
          autoComplete="off"
          onSubmit={event => {
            event.preventDefault();
            openSearchPage();
          }}
        >
          <InputGroup className="max-md:rounded-full max-md:border-transparent max-md:bg-muted md:w-56 lg:w-72">
            <InputGroupAddon>
              {open && isMobile ? (
                <InputGroupButton
                  size="icon-xs"
                  aria-label={t($ => $.web.search.closeSearch)}
                  onClick={() => {
                    setText('');
                    setOpen(false);
                    // Hides the keyboard
                    inputRef.current?.blur();
                  }}
                >
                  <ArrowLeftIcon />
                </InputGroupButton>
              ) : (
                <SearchIcon />
              )}
            </InputGroupAddon>
            <Autocomplete.Input
              render={<InputGroupInput />}
              placeholder={t($ => $.core.search.search)}
              aria-label={t($ => $.core.search.search)}
              ref={inputRef}
              enterKeyHint="search"
              onFocus={() => {
                setOpen(true);
              }}
            />
          </InputGroup>
        </form>
      </search>
      <Autocomplete.Portal>
        <Autocomplete.Positioner
          side="bottom"
          align="end"
          sideOffset={8}
          className="isolate z-50 max-md:fixed! max-md:inset-x-0! max-md:top-16! max-md:bottom-0! max-md:transform-none!"
        >
          <Autocomplete.Popup
            aria-label={t($ => $.core.search.results)}
            className="flex w-[min(32rem,var(--available-width))] flex-col overflow-hidden rounded-lg bg-popover text-popover-foreground shadow-md ring-1 ring-foreground/10 max-md:size-full max-md:rounded-none max-md:bg-background max-md:shadow-none max-md:ring-0"
          >
            <div className="flex border-b border-border-subtle p-2 max-md:px-page">
              <InLibraryFilter />
            </div>
            <div className="max-h-[min(32rem,calc(var(--available-height)-3.5rem))] overflow-y-auto overscroll-contain max-md:max-h-none max-md:flex-1">
              <SearchStatus
                status={search.status}
                query={query.trim()}
                count={preview.length}
                retry={search.retry}
              />
              <Autocomplete.List className="flex flex-col gap-px p-2 empty:hidden max-md:px-page">
                {(option: Option) =>
                  option === SEE_ALL ? (
                    <Autocomplete.Item
                      key={SEE_ALL}
                      value={option}
                      onClick={openSearchPage}
                      className="sticky bottom-0 flex min-h-11 cursor-default items-center gap-2 rounded-md bg-popover px-2 text-sm text-muted-foreground outline-none select-none data-highlighted:bg-accent data-highlighted:text-foreground max-md:bg-background"
                    >
                      <span className="min-w-0 flex-1 truncate">
                        {t($ => $.web.search.seeAll, {query: text.trim()})}
                      </span>
                      {/* i18next-instrument-ignore: the key's symbol, the same in every language */}
                      <Kbd className="pointer-coarse:hidden">↵</Kbd>
                    </Autocomplete.Item>
                  ) : (
                    <Autocomplete.Item
                      key={`${option.content_type}/${option.tmdb_id}`}
                      value={option}
                      render={<Link {...contentLink(option)} />}
                      className="flex items-center gap-4 rounded-md p-2 outline-none data-highlighted:bg-accent"
                    >
                      <SearchResultSummary result={option} />
                    </Autocomplete.Item>
                  )
                }
              </Autocomplete.List>
            </div>
          </Autocomplete.Popup>
        </Autocomplete.Positioner>
      </Autocomplete.Portal>
    </Autocomplete.Root>
  );
}
