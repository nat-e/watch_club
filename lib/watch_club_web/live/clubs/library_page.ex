defmodule WatchClubWeb.Clubs.LibraryPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.ContentCard
  import WatchClubWeb.Components.Libraries.LibraryIcon

  alias WatchClub.Clubs.LibraryItemsSortOption
  alias WatchClub.Contents.ContentView
  alias WatchClub.Shared.SortOrder
  alias WatchClubWeb.Clubs.LibraryPage.ContentStreamState

  @contents_page_size 40

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:contents, dom_id: &"library-content-#{ContentView.unique_id(&1)}")
     |> assign(:content_stream, ContentStreamState.initial())}
  end

  @impl true
  def render(%{library: %Library{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="!p-2"
      space="none"
    >
      <.stack space="group" class="w-full">
        <header class="flex w-full flex-col gap-related sm:flex-row sm:items-center sm:justify-between">
          <div class="flex min-w-0 flex-1 items-center gap-related">
            <span class="grid size-control-md shrink-0 place-items-center rounded-control border border-border bg-surface-raised text-text-muted">
              <.library_icon library={@library} class="size-icon" />
            </span>
            <h1 class="min-w-0 flex-1 truncate text-2xl font-bold">{@library.name}</h1>
          </div>
          <.library_sort_controls
            :if={!ContentStreamState.empty?(@content_stream)}
            club_id={@library.club_id}
            library_id={@library.id}
            current_sort_by={@sort_by}
            current_sort_order={@sort_order}
          />
        </header>

        <.empty :if={ContentStreamState.empty?(@content_stream)}>
          <:icon><Lucideicons.library /></:icon>
          <:title>{dgettext("clubs", "Library is empty")}</:title>
          <:description>
            {dgettext("clubs", "This library does not have any content yet.")}
          </:description>
        </.empty>

        <div
          :if={!ContentStreamState.empty?(@content_stream)}
          id="library-content-stream"
          phx-update="stream"
          class="grid grid-cols-[repeat(auto-fill,minmax(10rem,1fr))] gap-group"
        >
          <div :for={{dom_id, content} <- @streams.contents} id={dom_id} class="w-full">
            <.content_card content={content} library_id_context={@library.id} />
          </div>
        </div>

        <.infinite_scroll_trigger
          :if={ContentStreamState.can_load_more?(@content_stream)}
          id="library-content-load-more"
          event="load_more_contents"
        />
      </.stack>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}></Layouts.app>
    """
  end

  attr :club_id, :string, required: true
  attr :current_sort_by, :atom, required: true
  attr :current_sort_order, :atom, required: true
  attr :library_id, :string, required: true

  defp library_sort_controls(assigns) do
    ~H"""
    <div class="flex max-w-full items-center justify-end gap-related overflow-x-auto pb-tight sm:pb-0">
      <div
        role="group"
        aria-label={dgettext("clubs", "Library sort order")}
        class="flex shrink-0 gap-tight"
      >
        <.sort_toggle_button
          club_id={@club_id}
          library_id={@library_id}
          current_sort_by={@current_sort_by}
          current_sort_order={@current_sort_order}
          sort_by={:title}
          default_order={:asc}
          asc_icon={:arrow_down_a_z}
          desc_icon={:arrow_down_z_a}
          label={dgettext("clubs", "Title")}
        />
        <.sort_toggle_button
          club_id={@club_id}
          library_id={@library_id}
          current_sort_by={@current_sort_by}
          current_sort_order={@current_sort_order}
          sort_by={:added_date}
          default_order={:desc}
          asc_icon={:calendar_arrow_down}
          desc_icon={:calendar_arrow_up}
          label={dgettext("clubs", "Added date")}
        />
        <.sort_toggle_button
          club_id={@club_id}
          library_id={@library_id}
          current_sort_by={@current_sort_by}
          current_sort_order={@current_sort_order}
          sort_by={:release_date}
          default_order={:desc}
          asc_icon={:calendar_arrow_down}
          desc_icon={:calendar_arrow_up}
          label={dgettext("clubs", "Release date")}
        />
      </div>
    </div>
    """
  end

  attr :club_id, :string, required: true
  attr :current_sort_by, :atom, required: true
  attr :current_sort_order, :atom, required: true
  attr :sort_by, :atom, required: true
  attr :default_order, :atom, required: true
  attr :asc_icon, :atom, required: true
  attr :desc_icon, :atom, required: true
  attr :label, :string, required: true
  attr :library_id, :string, required: true

  defp sort_toggle_button(assigns) do
    active? = assigns.current_sort_by == assigns.sort_by

    target_sort_order =
      if active? do
        SortOrder.switch(assigns.current_sort_order)
      else
        assigns.default_order
      end

    target_icon =
      if active? do
        case assigns.current_sort_order do
          :asc -> assigns.asc_icon
          :desc -> assigns.desc_icon
        end
      else
        case target_sort_order do
          :asc -> assigns.asc_icon
          :desc -> assigns.desc_icon
        end
      end

    assigns =
      assigns
      |> assign(:active?, active?)
      |> assign(:target_sort_order, target_sort_order)
      |> assign(:target_icon, target_icon)

    ~H"""
    <.button
      id={"library-sort-#{@sort_by}-button"}
      patch={library_sort_path(@club_id, @library_id, @sort_by, @target_sort_order)}
      replace
      variant={(@active? && "accent") || "secondary"}
      aria-pressed={to_string(@active?)}
      aria-label={
        dgettext("clubs", "Sort by %{field} %{order}",
          field: @label,
          order: SortOrder.translated_label(@target_sort_order)
        )
      }
    >
      <:icon position="start">
        {apply(Lucideicons, @target_icon, [%{__changed__: %{}}])}
      </:icon>
      {@label}
    </.button>
    """
  end

  @impl true
  def handle_params(%{"club_id" => club_id, "library_id" => library_id} = params, _uri, socket) do
    {sort_by, sort_order} = LibraryItemsSortOption.parse_param(params["sort"])

    if params["sort"] != LibraryItemsSortOption.to_param(sort_by, sort_order) and
         connected?(socket) do
      {:noreply,
       push_patch(socket,
         to: library_sort_path(club_id, library_id, sort_by, sort_order),
         replace: true
       )}
    else
      load_library(socket, club_id, library_id, sort_by, sort_order)
    end
  end

  @impl true
  def handle_event("load_more_contents", _params, socket) do
    %{
      content_stream: content_stream,
      current_user: current_user,
      library: library,
      sort_by: sort_by,
      sort_order: sort_order
    } = socket.assigns

    if ContentStreamState.can_load_more?(content_stream) do
      page =
        load_contents_page(
          library.id,
          sort_by,
          sort_order,
          content_stream.next_keyset,
          current_user
        )

      {:noreply,
       socket
       |> assign(:content_stream, ContentStreamState.append(content_stream, page))
       |> stream(:contents, page.contents, at: -1)}
    else
      {:noreply, socket}
    end
  end

  defp load_library(socket, club_id, library_id, sort_by, sort_order) do
    current_user = socket.assigns.current_user

    case Clubs.get_library_by_id(library_id, actor: current_user) do
      {:ok, %Library{club_id: ^club_id} = library} ->
        page = load_contents_page(library.id, sort_by, sort_order, nil, current_user)

        {:noreply,
         socket
         |> assign(
           library: library,
           content_stream: ContentStreamState.reset(page),
           sort_by: sort_by,
           sort_order: sort_order
         )
         |> stream(:contents, page.contents, reset: true)}

      {:ok, %Library{}} ->
        not_found(socket)

      {:error, %Ash.Error.Query.NotFound{}} ->
        not_found(socket)

      {:error, %Ash.Error.Invalid{}} ->
        not_found(socket)

      {:error, %Ash.Error.Forbidden{}} ->
        not_found(socket)
    end
  end

  defp load_contents_page(library_id, sort_by, sort_order, after_keyset, current_user) do
    page_opts = [limit: @contents_page_size]
    page_opts = if after_keyset, do: Keyword.put(page_opts, :after, after_keyset), else: page_opts

    page =
      Clubs.get_library_items!(library_id, %{sort_by: sort_by, sort_order: sort_order},
        actor: current_user,
        page: page_opts
      )

    locale = current_user.settings.locale

    contents =
      Enum.map(page.results, fn item -> ContentView.from_content(item.content, locale) end)

    next_keyset =
      case List.last(page.results) do
        nil -> nil
        item -> item.__metadata__.keyset
      end

    %{contents: contents, more?: page.more?, next_keyset: next_keyset}
  end

  defp library_sort_path(club_id, library_id, sort_by, sort_order) do
    ~p"/clubs/#{club_id}/libraries/#{library_id}?#{[sort: LibraryItemsSortOption.to_param(sort_by, sort_order)]}"
  end

  defp not_found(socket) do
    {:noreply,
     socket
     |> put_flash(:error, dgettext("clubs", "The library you were looking for does not exist"))
     |> push_navigate(to: ~p"/")}
  end
end
