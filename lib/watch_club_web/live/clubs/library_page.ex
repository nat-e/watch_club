defmodule WatchClubWeb.Clubs.LibraryPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.ContentCard

  alias WatchClub.Clubs.LibraryItemsSortOption
  alias WatchClub.Contents.ContentView
  alias WatchClub.Shared.SortOrder
  alias WatchClubWeb.Helpers.KeysetStreamState

  @contents_page_size 40

  on_mount {WatchClubWeb.Hooks.LoadClub, false}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:subscribed_content_topics, [])
     |> stream_configure(:contents, dom_id: &"library-content-#{ContentView.unique_id(&1)}")}
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
  def render(%{library: %Library{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="p-2!"
      space="none"
    >
      <.stack space="group" class="w-full @container">
        <.stack space="related">
          <.inline space="related">
            <h1 class="min-w-0 flex-1 truncate text-3xl font-bold">{@library.name}</h1>
          </.inline>
          <.library_sort_controls
            club_id={@library.club_id}
            library_id={@library.id}
            current_sort_by={@sort_by}
            current_sort_order={@sort_order}
          />
        </.stack>

        <div
          id="library-content-stream"
          phx-update="stream"
          class="grid grid-cols-[repeat(auto-fill,minmax(10rem,1fr))] @5xl:grid-cols-[repeat(auto-fill,minmax(11rem,1fr))] gap-group"
        >
          <div id="library-content-empty" class="only:block hidden col-span-full">
            <.empty>
              <:icon><Lucideicons.library /></:icon>
              <:title>{dgettext("clubs", "Library is empty")}</:title>
              <:description>
                {dgettext("clubs", "This library does not have any content yet.")}
              </:description>
            </.empty>
          </div>

          <.content_card
            :for={{dom_id, content} <- @streams.contents}
            id={dom_id}
            content={content}
            library_id_context={@library.id}
            current_user={@current_user}
          />
        </div>

        <.infinite_scroll_trigger
          :if={KeysetStreamState.can_load_more?(@stream_state)}
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

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          payload: %Ash.Notifier.Notification{
            metadata: %{subject: :content_changed, content_id: content_id}
          }
        },
        socket
      ) do
    content =
      content_id
      |> Contents.view_content_by_id!(actor: socket.assigns.current_user)
      |> ContentView.from_content()

    {:noreply, socket |> stream_insert(:contents, content, update_only: true)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  attr :club_id, :string, required: true
  attr :current_sort_by, :atom, required: true
  attr :current_sort_order, :atom, required: true
  attr :library_id, :string, required: true

  defp library_sort_controls(assigns) do
    ~H"""
    <div
      role="group"
      aria-label={dgettext("clubs", "Library sort order")}
      class="flex flex-wrap items-center justify-end gap-tight"
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
  def handle_event("load_more_contents", _params, socket) do
    stream_state = socket.assigns.stream_state

    if KeysetStreamState.can_load_more?(stream_state) do
      {:noreply, load_contents_page(socket, stream_state)}
    else
      {:noreply, socket}
    end
  end

  defp load_library(socket, club_id, library_id, sort_by, sort_order) do
    current_user = socket.assigns.current_user

    case Clubs.get_library_by_id(library_id, actor: current_user) do
      {:ok, %Library{club_id: ^club_id} = library} ->
        stream_state = KeysetStreamState.init(@contents_page_size)

        {:noreply,
         socket
         |> assign(library: library, sort_by: sort_by, sort_order: sort_order)
         |> assign(:stream_state, stream_state)
         |> load_contents_page(stream_state)}

      _ ->
        not_found(socket)
    end
  end

  # Loads one keyset page of the library's contents. `load_page` derives the
  # cursor from the raw `LibraryItem`s' metadata; we then map them to
  # `ContentView`s (which carry no keyset) for the stream.
  defp load_contents_page(socket, %KeysetStreamState{} = stream_state) do
    %{library: library, sort_by: sort_by, sort_order: sort_order, current_user: current_user} =
      socket.assigns

    load =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        Clubs.get_library_items(library.id, %{sort_by: sort_by, sort_order: sort_order},
          actor: current_user,
          page: page_options
        )
      end)

    case load do
      {:ok, new_state, items} ->
        contents =
          Enum.map(items, &ContentView.from_content(&1.content))

        reset = stream_state.status == :init

        socket
        |> maybe_reset_subscriptions(reset)
        |> subscribe_to_contents(contents)
        |> assign(:stream_state, new_state)
        |> stream(:contents, contents, reset: reset)

      {:error, new_state, _} ->
        socket
        |> assign(:stream_state, new_state)
        |> put_flash(:error, dgettext("clubs", "There was an error loading the library"))
    end
  end

  defp maybe_reset_subscriptions(socket, false), do: socket

  defp maybe_reset_subscriptions(socket, true) do
    if connected?(socket) do
      socket.assigns.subscribed_content_topics
      |> Enum.each(&Phoenix.PubSub.unsubscribe(WatchClub.PubSub, &1))
    end

    socket |> assign(:subscribed_content_topics, [])
  end

  defp subscribe_to_contents(socket, contents) do
    if connected?(socket) do
      topics =
        contents
        |> Enum.flat_map(&WatchClub.PubSub.subscribe_to_content(&1, socket.assigns.current_user))

      socket
      |> assign(
        :subscribed_content_topics,
        socket.assigns.subscribed_content_topics ++ topics
      )
    else
      socket
    end
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
