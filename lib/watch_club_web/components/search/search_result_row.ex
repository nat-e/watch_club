defmodule WatchClubWeb.Components.Search.SearchResultRow do
  @moduledoc """
  A search result: poster, title, type, year and the clubs that already have it. Links to its
  page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.SearchResult

  attr :id, :string, required: true
  attr :result, SearchResult, required: true
  attr :overview, :boolean, default: false, doc: "shows the overview under the title"
  attr :class, :any, default: nil
  attr :rest, :global, doc: "e.g. `role=\"option\"` inside a combobox"

  def search_result_row(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={Url.content_details_link(@result.identity)}
      class={[
        "flex items-center gap-group rounded-control p-related transition-colors hover:bg-surface-hover aria-selected:bg-surface-hover focus-visible:-outline-offset-2",
        @class
      ]}
      {@rest}
    >
      <.tmdb_poster
        path={@result.poster_path}
        size="w154"
        class={["shrink-0", @overview && "w-16 @lg:w-20", !@overview && "w-12"]}
      />
      <span class="flex min-w-0 flex-1 flex-col gap-tight">
        <span class="truncate font-semibold text-text">{@result.title}</span>
        <span class="flex flex-wrap items-center gap-x-related gap-y-tight text-sm text-text-muted">
          <span class="inline-flex items-center gap-tight">
            <.content_type_icon type={@result.identity.type} class="size-icon-sm text-text-subtle" />
            {ContentType.translated_label(@result.identity.type)}
          </span>
          <span :if={@result.year} aria-hidden="true">·</span>
          <span :if={@result.year}>{@result.year}</span>
          <span
            :if={@result.clubs != []}
            class="inline-flex min-w-0 items-center gap-tight text-accent"
          >
            <Lucideicons.library class="size-icon-sm shrink-0" />
            <span class="truncate">
              {dgettext("search", "In %{clubs}", clubs: Enum.map_join(@result.clubs, ", ", & &1.name))}
            </span>
          </span>
        </span>
        <span
          :if={@overview and @result.overview}
          class="line-clamp-2 max-w-readable text-sm text-text-subtle"
        >
          {@result.overview}
        </span>
      </span>
    </.link>
    """
  end
end
