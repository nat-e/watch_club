defmodule WatchClubWeb.Components.Search.SearchResultRow do
  @moduledoc """
  A search result: poster, title, type, year and whether it's in the Library. Links to its page.
  Its summary also shows a search result that's picked rather than opened.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.SearchResult

  attr :id, :string, required: true
  attr :result, SearchResult, required: true
  attr :overview, :boolean, default: false, doc: "shows the overview under the title"
  attr :instance_name, :string, required: true, doc: "says it's in the Library"
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
      <.search_result_summary result={@result} overview={@overview} instance_name={@instance_name} />
    </.link>
    """
  end

  attr :result, SearchResult, required: true
  attr :overview, :boolean, default: false, doc: "shows the overview under the title"
  attr :type, :boolean, default: true, doc: "shows the Content Type"
  attr :instance_name, :string, required: true, doc: "says it's in the Library"
  slot :facts, doc: "other facts under the title, instead of its type, year and Library"

  @doc "A search result's poster, title and facts, for a row to wrap."
  def search_result_summary(assigns) do
    ~H"""
    <.tmdb_poster
      path={@result.poster_path}
      size="w154"
      class={["shrink-0", @overview && "w-16 @lg:w-20", !@overview && "w-12"]}
    />
    <span class="flex min-w-0 flex-1 flex-col gap-tight">
      <span class="truncate font-semibold text-text">{@result.title}</span>
      <span class="flex flex-wrap items-center gap-x-related gap-y-tight text-sm text-text-muted">
        {render_slot(@facts)}
        <%= if @facts == [] do %>
          <span :if={@type} class="inline-flex items-center gap-tight">
            <.content_type_icon type={@result.identity.type} class="size-icon-sm text-text-subtle" />
            {ContentType.translated_label(@result.identity.type)}
          </span>
          <span :if={@type and @result.year} aria-hidden="true">·</span>
          <span :if={@result.year}>{@result.year}</span>
          <span
            :if={@result.has_media?}
            class="inline-flex min-w-0 items-center gap-tight text-accent"
          >
            <Lucideicons.library class="size-icon-sm shrink-0" />
            <span class="truncate">{dgettext("search", "On %{name}", name: @instance_name)}</span>
          </span>
        <% end %>
      </span>
      <span
        :if={@overview and @result.overview}
        class="line-clamp-2 max-w-readable text-sm text-text-subtle"
      >
        {@result.overview}
      </span>
    </span>
    """
  end
end
