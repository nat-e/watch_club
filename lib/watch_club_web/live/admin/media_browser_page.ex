defmodule WatchClubWeb.Admin.MediaBrowserPage do
  @moduledoc """
  The Media Browser, where the Instance Administrator finds a Media, spots the Unmatched ones or
  sees what was just added, then plays, matches or removes it from its details beside the list. The list
  shows 20 Media a page. Its search, filters, sort and page, and the selected Media, live in the
  URL, so Back after Play returns to the same place.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Admin.MediaBrowserPage.MediaDetails
  import WatchClubWeb.Admin.MediaBrowserPage.MediaTable
  import WatchClubWeb.Admin.MediaBrowserPage.RemoveMediaModal
  import WatchClubWeb.Components.Media.MediaTypeBadge

  alias WatchClub.Shared.SortOrder
  alias WatchClubWeb.Admin.MediaBrowserPage.MatchMediaLive

  @page_size 20
  @sorts [:added, :title]
  @row_load [
    content: [:title, :poster_path],
    video: [:audio_tracks, :text_tracks, parts: [:tv_show_episode]]
  ]
  @details_load [
    content: [:title, :poster_path],
    video: [:default_video_track, :audio_tracks, :text_tracks, parts: [:tv_show_episode]]
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_if_connected("content:global")
     # The Media the Match and Remove media dialogs are about
     |> assign(list: nil, matching: nil, removing: nil)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      assign(socket, :selected, selected_media(params["media"], socket.assigns.current_user))

    list = list(params)

    # Opening or closing a Media's details keeps the list as it is
    if list == socket.assigns.list,
      do: {:noreply, socket},
      else: {:noreply, socket |> assign(:list, list) |> load_list!()}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket),
    do: {:noreply, patch_list(socket, search: String.trim(search))}

  # One Media Type at a time: choosing the one that's on turns it off
  def handle_event("filter_type", %{"type" => type}, socket) do
    type = Url.parse_url_param(type, MediaType.values())
    type = if type == socket.assigns.list.media_type, do: nil, else: type
    {:noreply, patch_list(socket, media_type: type)}
  end

  def handle_event("toggle_unmatched", _params, socket),
    do: {:noreply, patch_list(socket, unmatched?: not socket.assigns.list.unmatched?)}

  def handle_event("clear_filters", _params, socket),
    do: {:noreply, patch_list(socket, search: "", media_type: nil, unmatched?: false)}

  # A column first sorts in its own order, then reverses it
  def handle_event("sort", %{"by" => by}, socket) do
    %{sort_by: sort_by, sort_order: sort_order} = socket.assigns.list
    by = Url.parse_url_param(by, @sorts, sort_by)
    order = if by == sort_by, do: SortOrder.switch(sort_order), else: first_order(by)
    {:noreply, patch_list(socket, sort_by: by, sort_order: order)}
  end

  def handle_event("go_to_page", %{"page" => page}, socket),
    do: {:noreply, patch_list(socket, page: String.to_integer(page))}

  def handle_event("select", %{"id" => id}, socket),
    do: {:noreply, push_patch(socket, to: media_browser_path(socket.assigns.list, id))}

  def handle_event("close_details", _params, socket),
    do: {:noreply, push_patch(socket, to: media_browser_path(socket.assigns.list, nil))}

  def handle_event("open_match_media_modal", _params, socket),
    do: {:noreply, assign(socket, :matching, socket.assigns.selected)}

  def handle_event("regenerate_thumbnails_and_markers", _params, socket) do
    MediaCatalog.regenerate_thumbnails_and_markers!(socket.assigns.selected.video,
      actor: socket.assigns.current_user
    )

    {:noreply,
     put_flash(
       socket,
       :info,
       dgettext("admin_media", "Thumbnails and markers will be regenerated in the background.")
     )}
  end

  def handle_event("open_remove_media_modal", _params, socket),
    do: {:noreply, assign(socket, :removing, socket.assigns.selected)}

  def handle_event("close_remove_media_modal", _params, socket),
    do: {:noreply, assign(socket, :removing, nil)}

  # The list reloads from the Media's notification
  def handle_event("delete_media", _params, socket) do
    MediaCatalog.destroy_media!(socket.assigns.removing, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:removing, nil)
     |> put_flash(:info, dgettext("admin_media", "Media removed."))
     |> push_patch(to: media_browser_path(socket.assigns.list, nil))}
  end

  # A Media was added, moved or removed, or a Content's titles or posters changed
  @impl true
  def handle_info(%Notification{resource: resource}, socket) when resource in [Media, Content] do
    %{selected: selected, current_user: user} = socket.assigns

    {:noreply,
     socket
     |> load_list!()
     |> assign(:selected, selected && selected_media(selected.id, user))}
  end

  def handle_info(%Notification{}, socket), do: {:noreply, socket}

  def handle_info(:close_match_media_modal, socket),
    do: {:noreply, assign(socket, :matching, nil)}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :locale, assigns.current_user.settings.locale)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      title={dgettext("admin_media", "Media Browser")}
    >
      <:parent
        :if={@selected}
        navigate={media_browser_path(@list, nil)}
        label={dgettext("admin_media", "Media Browser")}
        patch
        narrow_only
      />

      <%!-- Narrow screens show the selected Media's details instead of the list --%>
      <div class={@selected && "@max-split-view/main:hidden"}>
        <.page_description text={
          dgettext("admin_media", "View and manage all Media on this instance.")
        } />
      </div>

      <.no_media :if={@media_page.count == 0 and not filtered?(@list)} />

      <%!-- min-w-0, or the chips widen the page instead of scrolling --%>
      <div
        :if={@media_page.count > 0 or filtered?(@list)}
        class="flex min-w-0 items-start gap-cluster"
      >
        <div class={[
          "flex min-w-0 flex-3 flex-col gap-group",
          @selected && "@max-split-view/main:hidden"
        ]}>
          <.filters list={@list} unmatched_count={@unmatched_count} locale={@locale} />
          <.no_match :if={@media_page.count == 0} />
          <.media_table
            :if={@media_page.count > 0}
            media_page={@media_page}
            list={@list}
            selected_id={@selected && @selected.id}
            locale={@locale}
          />
        </div>

        <%!-- Beside the list, two fifths of the width up to 40rem, under the app bar as the list scrolls --%>
        <.card
          id="media-details"
          aria-label={dgettext("admin_media", "Media details")}
          padding="none"
          class={[
            "min-w-0 flex-2 max-w-160 @split-view/main:min-w-96",
            "@split-view/main:sticky @split-view/main:top-[calc(var(--wc-app-bar-height)+var(--spacing-group))] @split-view/main:max-h-[calc(100svh-var(--wc-app-bar-height)-2*var(--spacing-group))] @split-view/main:overflow-y-auto",
            !@selected && "@max-split-view/main:hidden"
          ]}
        >
          <.media_details :if={@selected} media={@selected} locale={@locale} />
          <.empty :if={!@selected} id="no-media-selected" border={false} class="py-section!">
            <:icon><Lucideicons.panel_right /></:icon>
            <:title>{dgettext("admin_media", "No file selected")}</:title>
            <:description>
              {dgettext("admin_media", "Select a file to see its details.")}
            </:description>
          </.empty>
        </.card>
      </div>

      <.live_component
        :if={@matching}
        id="match-media-modal"
        module={MatchMediaLive}
        media={@matching}
        current_user={@current_user}
        on_close={fn -> send(self(), :close_match_media_modal) end}
      />
      <.remove_media_modal :if={@removing} instance_settings={@instance_settings} />
    </Layouts.app>
    """
  end

  attr :list, :map, required: true
  attr :unmatched_count, :integer, required: true
  attr :locale, :atom, required: true

  # The search, then one chip per Media Type and one for the Unmatched Media, as on Browse
  defp filters(assigns) do
    assigns = assign(assigns, :form, to_form(%{"search" => assigns.list.search}))

    ~H"""
    <div class="flex flex-col gap-group">
      <.form
        id="media-search"
        for={@form}
        layout="none"
        role="search"
        phx-change="search"
        phx-submit="search"
      >
        <div class="relative">
          <Lucideicons.search
            aria-hidden="true"
            class="pointer-events-none absolute top-1/2 left-3 size-icon-sm -translate-y-1/2 text-text-subtle"
          />
          <.input
            id="media-search-input"
            field={@form[:search]}
            type="search"
            placeholder={dgettext("admin_media", "Search file name or title")}
            aria-label={dgettext("admin_media", "Search Media")}
            autocomplete="off"
            phx-debounce="300"
            class="pl-9!"
          />
        </div>
      </.form>
      <.scroll_row id="media-filters" variant="chips">
        <div
          role="radiogroup"
          aria-label={dgettext("admin_media", "Media Type")}
          class="flex shrink-0 items-center gap-related"
        >
          <.filter_chip
            :for={type <- MediaType.values()}
            id={"filter-#{type}"}
            on={@list.media_type == type}
            radio
            phx-click="filter_type"
            phx-value-type={type}
          >
            <:icon><.media_type_icon media_type={type} /></:icon>
            {MediaType.translated_plural_label(type)}
          </.filter_chip>
        </div>
        <span class="h-6 w-px shrink-0 bg-border-subtle" aria-hidden="true"></span>
        <.filter_chip id="filter-unmatched" on={@list.unmatched?} phx-click="toggle_unmatched">
          <:icon><Lucideicons.file_question_mark /></:icon>
          {dgettext("admin_media", "Unmatched")}
          <span class="font-normal tabular-nums">
            {WatchClub.Cldr.Number.to_string!(@unmatched_count,
              locale: UserLocale.to_cldr_locale_name(@locale)
            )}
          </span>
        </.filter_chip>
      </.scroll_row>
    </div>
    """
  end

  defp no_media(assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.search /></:icon>
      <:title>{dgettext("admin_media", "You don't have any media yet")}</:title>
      <:description>
        {dgettext(
          "admin_media",
          "Configure media imports or automations to add Media to your instance."
        )}
      </:description>
      <.button id="empty-state-import-media" navigate={~p"/admin/media/sources"} variant="primary">
        <:icon><Lucideicons.download /></:icon>
        {dgettext("admin_media", "Import Media")}
      </.button>
    </.empty>
    """
  end

  defp no_match(assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.search_x /></:icon>
      <:title>{dgettext("admin_media", "No Media match your filters")}</:title>
      <:description>
        {dgettext("admin_media", "Try clearing your filters or searching for something else")}
      </:description>
      <.button id="empty-state-clear-filters" phx-click="clear_filters" variant="accent">
        <:icon><Lucideicons.x /></:icon>
        {dgettext("admin_media", "Clear filters")}
      </.button>
    </.empty>
    """
  end

  # The list's search, filters, sort and page in the URL. Unknown values are left out.
  defp list(params) do
    sort_by = Url.parse_url_param(params["sort"], @sorts, :added)

    %{
      search: if(is_binary(params["search"]), do: params["search"], else: ""),
      media_type: Url.parse_url_param(params["type"], MediaType.values()),
      unmatched?: params["unmatched"] == "true",
      sort_by: sort_by,
      sort_order: Url.parse_url_param(params["order"], SortOrder.values(), first_order(sort_by)),
      page: page_number(params["page"])
    }
  end

  defp page_number(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _other -> 1
    end
  end

  defp page_number(_page), do: 1

  defp first_order(:title), do: :asc
  defp first_order(:added), do: :desc

  defp filtered?(list), do: list.search != "" or list.media_type != nil or list.unmatched?

  # The list's URL, without its default values
  defp media_browser_path(list, media_id) do
    params =
      Enum.reject(
        [
          search: list.search,
          type: list.media_type,
          unmatched: list.unmatched?,
          sort: list.sort_by != :added && list.sort_by,
          order: list.sort_order != first_order(list.sort_by) && list.sort_order,
          page: list.page != 1 && list.page,
          media: media_id
        ],
        fn {_param, value} -> value in [nil, false, ""] end
      )

    ~p"/admin/media?#{params}"
  end

  # Changing the search, a filter or the sort goes back to the first page
  defp patch_list(socket, changes) do
    list = Map.merge(%{socket.assigns.list | page: 1}, Map.new(changes))
    push_patch(socket, to: media_browser_path(list, selected_id(socket)))
  end

  defp selected_id(%{assigns: %{selected: %Media{id: id}}}), do: id
  defp selected_id(_socket), do: nil

  defp load_list!(socket) do
    %{list: list, current_user: user} = socket.assigns

    media_page =
      MediaCatalog.browse_media!(Map.delete(list, :page),
        page: [limit: @page_size, offset: (list.page - 1) * @page_size],
        load: @row_load,
        actor: user
      )

    last_page = max(AshPhoenix.LiveView.last_page(media_page), 1)

    # A page past the last one, after removals or from an old link
    if list.page > last_page do
      socket
      |> assign(:list, %{list | page: last_page})
      |> load_list!()
      |> push_patch(
        to: media_browser_path(%{list | page: last_page}, selected_id(socket)),
        replace: true
      )
    else
      assign(socket,
        media_page: media_page,
        unmatched_count:
          MediaCatalog.count_unmatched_media!(Map.take(list, [:search, :media_type]),
            actor: user
          )
      )
    end
  end

  # The Media of the URL, unless a hand-edited URL or a removal makes it unknown
  defp selected_media(nil, _user), do: nil

  defp selected_media(id, user) do
    case MediaCatalog.get_media(id, load: @details_load, actor: user) do
      {:ok, media} -> media
      {:error, %Ash.Error.Invalid{}} -> nil
    end
  end
end
