defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaTable do
  @moduledoc """
  One page of the Media Browser's list: what each Media is, its Media Type, its audio and
  subtitle languages and when it was added, with the pages in its footer. Title and Added sort
  the list. The columns keep their widths from page to page, the narrowest screens hide them
  first, and phones show the date under the name.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaBrowserPage.Filename
  import WatchClubWeb.Admin.MediaBrowserPage.MediaPoster
  import WatchClubWeb.Components.Media.MediaTypeBadge
  import WatchClubWeb.Components.Medias.LanguageFlags

  attr :media_page, Ash.Page.Offset,
    required: true,
    doc: "with each Media's `content`'s `implementation`, and its `video`'s tracks and episode"

  attr :list, :map, required: true, doc: "the page's sort and page number"
  attr :selected_id, :string, default: nil
  attr :locale, :atom, required: true

  def media_table(assigns) do
    ~H"""
    <.table id="media-table" class="@container/table">
      <.table_header>
        <.table_row>
          <.sort_head by={:title} list={@list} class="w-full max-w-0">
            {dgettext("admin_media", "Title")}
          </.sort_head>
          <.table_head class="min-w-44 text-left! @max-xl/table:hidden">
            {dgettext("admin_media", "Media Type")}
          </.table_head>
          <.table_head class="min-w-24 text-left! @max-3xl/table:hidden">
            {dgettext("admin_media", "Audio")}
          </.table_head>
          <.table_head class="min-w-32 text-left! @max-3xl/table:hidden">
            {dgettext("admin_media", "Subtitles")}
          </.table_head>
          <.sort_head by={:added} list={@list} class="min-w-40 @max-sm/table:hidden">
            {dgettext("admin_media", "Added")}
          </.sort_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.media_row
          :for={media <- @media_page.results}
          media={media}
          selected={media.id == @selected_id}
          locale={@locale}
        />
      </.table_body>
      <.table_footer class="font-normal!">
        <tr>
          <td colspan="5" class="px-group py-related">
            <.pagination media_page={@media_page} page={@list.page} locale={@locale} />
          </td>
        </tr>
      </.table_footer>
    </.table>
    """
  end

  attr :by, :atom, required: true
  attr :list, :map, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  # Sorts by its column, then reverses
  defp sort_head(assigns) do
    assigns =
      assign(assigns, :order, assigns.list.sort_by == assigns.by && assigns.list.sort_order)

    ~H"""
    <.table_head
      class={["text-left!", @class]}
      aria-sort={@order && if(@order == :asc, do: "ascending", else: "descending")}
    >
      <button
        type="button"
        phx-click="sort"
        phx-value-by={@by}
        class={[
          "-ml-related inline-flex h-control-sm items-center gap-tight rounded-control px-related uppercase transition-colors hover:bg-surface-hover hover:text-text",
          @order && "text-text"
        ]}
      >
        {render_slot(@inner_block)}
        <Lucideicons.arrow_up :if={@order == :asc} class="size-icon-sm" />
        <Lucideicons.arrow_down :if={@order == :desc} class="size-icon-sm" />
        <Lucideicons.chevrons_up_down :if={!@order} class="size-icon-sm text-text-subtle" />
      </button>
    </.table_head>
    """
  end

  attr :media, Media, required: true
  attr :selected, :boolean, required: true
  attr :locale, :atom, required: true

  defp media_row(assigns) do
    assigns =
      assign(assigns,
        file_name: Path.basename(assigns.media.path),
        added: Time.relative_or_date(assigns.media.inserted_at, assigns.locale),
        episode: assigns.media.video && assigns.media.video.tv_show_episode
      )

    ~H"""
    <.table_row
      id={"media-#{@media.id}"}
      selected={@selected}
      phx-click="select"
      phx-value-id={@media.id}
      class="cursor-pointer"
    >
      <.media_cell class="w-full max-w-0">
        <div class="flex min-w-0 items-center gap-group">
          <.media_poster media={@media} size="sm" />
          <div class="flex min-w-0 flex-1 flex-col gap-tight">
            <%!-- The whole row opens the Media's details; its name is the button keyboards reach --%>
            <button
              type="button"
              class="block w-full min-w-0 text-left focus-visible:-outline-offset-2"
            >
              <span :if={@media.content} class="flex min-w-0 items-center gap-related">
                <span class="truncate font-semibold text-text">{content_title(@media.content)}</span>
                <.badge :if={@episode} variant="secondary" size="sm" class="shrink-0 tabular-nums">
                  {@episode.formatted_episode_number}
                </.badge>
                <span :if={!@episode} class="shrink-0 text-text-subtle">
                  {Time.maybe_year(@media.content.release_date)}
                </span>
              </span>
              <.file_name
                :if={!@media.content}
                file_name={@file_name}
                class="font-semibold text-text"
              />
            </button>
            <div class="flex min-w-0 items-center gap-related">
              <.file_name
                :if={@media.content}
                file_name={@file_name}
                class="flex-1 text-xs text-text-subtle"
              />
              <div :if={!@media.content} class="flex-1">
                <.badge variant="accent" size="sm">
                  <:icon><Lucideicons.file_question_mark /></:icon>
                  {dgettext("admin_media", "Unmatched")}
                </.badge>
              </div>
              <time class="shrink-0 text-xs whitespace-nowrap text-text-subtle @sm/table:hidden">
                {@added}
              </time>
            </div>
          </div>
        </div>
      </.media_cell>
      <.media_cell class="text-text-muted @max-xl/table:hidden">
        <span class="flex items-center gap-related">
          <.media_type_icon media_type={@media.type} class="size-icon-sm shrink-0" />
          {MediaType.translated_label(@media.type)}
        </span>
      </.media_cell>
      <.media_cell class="@max-3xl/table:hidden">
        <.audio_languages_flags video={@media.video} />
      </.media_cell>
      <.media_cell class="@max-3xl/table:hidden">
        <.subtitle_languages_flags video={@media.video} />
      </.media_cell>
      <.media_cell class="text-text-muted @max-sm/table:hidden">
        <time class="whitespace-nowrap">{@added}</time>
      </.media_cell>
    </.table_row>
    """
  end

  attr :class, :any, default: nil
  slot :inner_block, required: true

  # Dense, and aligned to the start
  defp media_cell(assigns) do
    ~H"""
    <.table_cell class={["py-related! text-left!", @class]}>{render_slot(@inner_block)}</.table_cell>
    """
  end

  attr :media_page, Ash.Page.Offset, required: true
  attr :page, :integer, required: true
  attr :locale, :atom, required: true

  # Where this page is in the list, then the first and last pages and the ones around this one.
  # Phones show this page's number instead.
  defp pagination(assigns) do
    %{media_page: %{offset: offset, results: results, count: count}, locale: locale} = assigns
    last_page = AshPhoenix.LiveView.last_page(assigns.media_page)

    assigns =
      assign(assigns,
        range:
          gtspan(
            "#{number(offset + 1, locale)}–#{number(offset + length(results), locale)}",
            "text-text"
          ),
        count: number(count, locale),
        last_page: last_page,
        pages: pages_around(assigns.page, last_page)
      )

    ~H"""
    <div class="@container/pages flex flex-wrap items-center justify-between gap-x-group gap-y-related text-sm text-text-muted">
      <p class="tabular-nums">
        {raw(dgettext("admin_media", "%{range} of %{count}", range: @range, count: @count))}
      </p>
      <nav
        :if={@last_page > 1}
        aria-label={dgettext("admin_media", "Pages")}
        class="flex items-center gap-tight"
      >
        <.button
          id="previous-page"
          variant="ghost"
          size="icon-sm"
          phx-click="go_to_page"
          phx-value-page={@page - 1}
          disabled={@page == 1}
          aria-label={dgettext("admin_media", "Previous page")}
        >
          <Lucideicons.chevron_left />
        </.button>
        <%= for page <- @pages do %>
          <span :if={page == :gap} class="w-6 text-center @max-md/pages:hidden" aria-hidden="true">
            …
          </span>
          <.button
            :if={page != :gap}
            id={"page-#{page}"}
            variant="ghost"
            size="icon-sm"
            phx-click="go_to_page"
            phx-value-page={page}
            aria-current={page == @page && "page"}
            aria-label={dgettext("admin_media", "Page %{page}", page: page)}
            class={[
              "w-auto! min-w-(--spacing-control-sm) px-related! tabular-nums @max-md/pages:hidden",
              page == @page && "bg-surface-selected! text-text!"
            ]}
          >
            {page}
          </.button>
        <% end %>
        <span class="px-related tabular-nums @md/pages:hidden">
          {dgettext("admin_media", "Page %{page} of %{count}", page: @page, count: @last_page)}
        </span>
        <.button
          id="next-page"
          variant="ghost"
          size="icon-sm"
          phx-click="go_to_page"
          phx-value-page={@page + 1}
          disabled={@page == @last_page}
          aria-label={dgettext("admin_media", "Next page")}
        >
          <Lucideicons.chevron_right />
        </.button>
      </nav>
    </div>
    """
  end

  # The first and last pages and the ones next to this one, with gaps between them
  defp pages_around(page, last_page) do
    [1, page - 1, page, page + 1, last_page]
    |> Enum.filter(&(&1 in 1..last_page))
    |> Enum.uniq()
    |> Enum.chunk_every(2, 1)
    |> Enum.flat_map(fn
      [a, b] when b - a > 1 -> [a, :gap]
      [a | _rest] -> [a]
    end)
  end

  defp number(count, locale),
    do: WatchClub.Cldr.Number.to_string!(count, locale: UserLocale.to_cldr_locale_name(locale))
end
