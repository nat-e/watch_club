defmodule WatchClubWeb.BrowsePage do
  @moduledoc """
  Browse: the Library's posters, most recently added first. Signing in opens it.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClub.Contents.Content
  alias WatchClub.History.WatchProgress
  alias WatchClub.Languages
  alias WatchClub.MediaCatalog.Media
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Helpers.KeysetStreamState

  @page_size 40
  @content_fields [:implementation, :actor_progress_status]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("nav", "Browse")}
      search
      class="@container pt-group!"
    >
      <ul
        id="library"
        phx-update="stream"
        class="grid list-none grid-cols-3 gap-x-related gap-y-group p-0 @lg:grid-cols-[repeat(auto-fill,minmax(8.5rem,1fr))] @lg:gap-x-group"
      >
        <%!-- Shown only when it's the stream's sole child --%>
        <li id="library-empty" class="col-span-full hidden only:block">
          <.empty>
            <:icon><Lucideicons.clapperboard /></:icon>
            <:title>{dgettext("browse", "Nothing in the library yet")}</:title>
            <:description>
              {dgettext("browse", "Movies and TV shows show up here once they're on the server.")}
            </:description>
          </.empty>
        </li>
        <li :for={{dom_id, content} <- @streams.library} id={dom_id}>
          <.poster_card content={content} current_user={@current_user} />
        </li>
      </ul>

      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="library-load-more"
        event="load_more"
      />
    </Layouts.app>
    """
  end

  attr :content, Content, required: true
  attr :current_user, User, required: true

  # Its progress badge, and on hover its name, original language, year and Play
  defp poster_card(assigns) do
    assigns =
      assigns
      |> assign(:title, assigns.content.implementation.best_localization.title)
      |> assign(:identity, ContentIdentity.from_content(assigns.content))

    ~H"""
    <div class="group relative">
      <.tmdb_poster
        path={@content.implementation.best_localization.poster_path}
        size="w342"
        class="w-full shadow-card"
      >
        <.progress_badge status={@content.actor_progress_status} />
        <span
          aria-hidden="true"
          class="absolute inset-0 flex flex-col justify-end gap-related bg-linear-to-t from-black/90 via-black/60 to-transparent p-related opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100"
        >
          <span class="line-clamp-3 text-sm font-semibold text-white">{@title}</span>
          <span class="flex items-center gap-related text-xs text-white/80">
            <span
              :if={@content.original_language}
              class="text-base leading-none"
              title={
                dgettext("browse", "Original language: %{language}",
                  language: Languages.to_name(@content.original_language)
                )
              }
            >
              {Languages.to_flag(@content.original_language)}
            </span>
            <span :if={@content.release_date}>{@content.release_date.year}</span>
          </span>
        </span>
      </.tmdb_poster>
      <.link
        navigate={Url.content_details_link(@identity)}
        aria-label={@title}
        class="absolute inset-0 rounded-lg"
      ></.link>
      <div class="pointer-events-none absolute inset-0 grid place-items-center opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100 [&_a]:pointer-events-auto [&_button]:pointer-events-auto">
        <.live_component
          id={PlayOrRequestButtonLive.dom_id(@identity)}
          module={PlayOrRequestButtonLive}
          content_identity={@identity}
          current_user={@current_user}
          variant="round"
          play_only
        />
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp progress_badge(%{status: :completed} = assigns) do
    ~H"""
    <span
      role="img"
      aria-label={dgettext("browse", "Watched")}
      title={dgettext("browse", "Watched")}
      class="absolute top-related right-related grid size-7 place-items-center rounded-full bg-black/80"
    >
      <Lucideicons.check class="size-icon-sm text-success" />
    </span>
    """
  end

  defp progress_badge(%{status: :in_progress} = assigns) do
    ~H"""
    <span
      role="img"
      aria-label={dgettext("browse", "In progress")}
      title={dgettext("browse", "In progress")}
      class="absolute top-related right-related grid size-7 place-items-center rounded-full bg-black/80"
    >
      <Lucideicons.contrast class="size-icon-sm text-primary" />
    </span>
    """
  end

  defp progress_badge(assigns), do: ~H""

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> assign(:stream_state, KeysetStreamState.init(@page_size))
     |> load_page()}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.stream_state) do
      {:noreply, load_page(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%Notification{} = notification, socket) do
    PlayOrRequestButtonLive.handle_pubsub_message(notification, socket.assigns.current_user)

    case notification do
      %{resource: Content, data: %Content{id: id}} ->
        {:noreply, refresh_content(socket, id)}

      %{resource: Media, metadata: %{content_id: id}} ->
        {:noreply, refresh_content(socket, id)}

      %{resource: WatchProgress, metadata: %{content_id: id}} ->
        {:noreply, refresh_content(socket, id)}

      _other ->
        {:noreply, socket}
    end
  end

  defp load_page(socket) do
    %{stream_state: stream_state, current_user: user} = socket.assigns

    {:ok, new_state, contents} =
      KeysetStreamState.load_page(stream_state, fn page_options ->
        Contents.get_library(load: @content_fields, page: page_options, actor: user)
      end)

    socket
    |> assign(:stream_state, new_state)
    |> stream(:library, contents)
  end

  # A Content that joins the Library goes first, one that leaves it goes, and the others update in
  # place.
  defp refresh_content(socket, content_id) do
    case Contents.get_library!(
           query: [filter: [id: content_id]],
           load: @content_fields,
           actor: socket.assigns.current_user
         ) do
      [content] -> stream_insert(socket, :library, content, at: 0)
      [] -> stream_delete_by_dom_id(socket, :library, "library-#{content_id}")
    end
  end
end
