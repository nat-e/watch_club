defmodule WatchClubWeb.Live.Contents.Components.InYourClubsSectionLive do
  use WatchClubWeb, :live_component

  alias WatchClub.ActivityFeed.Preparations.LoadActivityFeedEvent

  alias WatchClubWeb.Components.Contents.AddToLibraryModalLive
  alias WatchClubWeb.Helpers.KeysetStreamState

  @feed_page_size 25

  @doc """
  The DOM id we recommend using for this Live Component
  Stable DOM id allows us to simplify PubSub notification handling
  """
  def dom_id, do: "iyc-section"

  @doc """
  Updates the component when a relevant Ash Notification is received.
  We recommend using it on every LiveView that uses this LiveComponent for reactivity.
  This requires using dom_id() as the ID for the LiveComponent and the LiveView to have
  subscribed to the correct topics via `WatchClub.PubSub.subscribe_to_current_user_content_topics`.

  The section refreshes when the content has been added or removed to a club
  """
  def handle_pubsub_message(
        %Notification{
          resource: LibraryItem,
          metadata: %{content_identity: identity}
        },
        content_identity
      )
      when identity == content_identity do
    send_update(__MODULE__, id: dom_id(), refresh_clubs: true)
  end

  # Note that we don't support deletion of deleted events (ContentWatched at the moment)
  # since they are not published.
  # Prepend or update an event in the feed
  # There is no need to check the content identity since content details page
  # only subscribe to a content specific topic
  def handle_pubsub_message(
        %Notification{data: %FeedEventScope{scope_club_id: scope_club_id} = event},
        _identity
      )
      when not is_nil(scope_club_id) do
    send_update(__MODULE__, id: dom_id(), feed_event_upserted: event)
  end

  # Ignore all other events
  def handle_pubsub_message(_msg, _identity), do: nil

  attr :content_identity, ContentIdentity, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-surface border border-border-subtle flex flex-col rounded-xl">
      <div class="flex gap-tight items-center p-group">
        <.inline class="flex-1">
          <span class="inline-flex size-control-md shrink-0 items-center justify-center text-accent">
            <.lucide_icon name={:users} class="size-icon" />
          </span>
          <div class="flex flex-col min-w-0 gap-tight">
            <h2 class="text-xl font-heading font-semibold tracking-tight text-text">
              {dgettext("contents", "In your clubs")}
            </h2>
          </div>
        </.inline>
        <.button
          :if={@clubs != []}
          id="iyc-share-button"
          variant="ghost"
          phx-click="open_add_to_library_modal"
          phx-target={@myself}
        >
          <:icon><Lucideicons.plus /></:icon>
          {dgettext("contents", "Share with another club")}
        </.button>
      </div>
      <.empty_state :if={@clubs == []} content_identity={@content_identity} myself={@myself} />
      <div :if={@clubs != []} class="flex border-t">
        <.stack
          space="tight"
          class="min-w-40 max-w-60 bg-surface-inset border-r rounded-bl-xl p-tight"
        >
          <.button
            :for={club <- @clubs}
            variant="ghost"
            id={"iyc-club-tab-button-#{club.id}"}
            class={[
              "p-related! h-16! justify-start",
              club.id == @selected_club_id && "bg-surface-selected!"
            ]}
            patch={
              Url.content_details_link(@content_identity.type, @content_identity.external_id, club.id)
            }
          >
            <.club_ref club={club} selected={club.id == @selected_club_id} />
          </.button>
        </.stack>
        <.activity_feed
          feed={@streams.feed}
          stream_state={@stream_state}
          current_user={@current_user}
          myself={@myself}
        />
      </div>
      <.live_component
        :if={@add_to_library_modal_open}
        id="iyc-add-to-library-modal"
        module={AddToLibraryModalLive}
        content_identity={@content_identity}
        content_title={@content_title}
        current_user={@current_user}
        on_close={
          fn ->
            send_update(__MODULE__, id: dom_id(), close_add_to_library_modal: true)
          end
        }
      />
    </div>
    """
  end

  attr :content_identity, ContentIdentity, required: true
  attr :myself, :any, required: true

  def empty_state(assigns) do
    ~H"""
    <.empty border={false}>
      <:description>
        {dgettext(
          "contents",
          "This %{type} is not present in any of your clubs yet.",
          type: ContentType.translated_label(@content_identity.type)
        )}<br />
        {dgettext(
          "contents",
          "Share it to make it available for everybody and start exchanging about it."
        )}
      </:description>
      <.button
        id="iyc-empty-share-button"
        variant="accent"
        phx-click="open_add_to_library_modal"
        phx-target={@myself}
      >
        <:icon><Lucideicons.plus /></:icon>
        {dgettext(
          "contents",
          "Share with club"
        )}
      </.button>
    </.empty>
    """
  end

  attr :feed, :list, required: true
  attr :stream_state, KeysetStreamState, required: true
  attr :current_user, User, required: true
  attr :myself, :any, required: true

  def activity_feed(assigns) do
    ~H"""
    <.stack
      id="content-activity-feed"
      phx-update="stream"
      as="ul"
      space="related"
      class="p-group flex-1 min-h-40 max-h-120 overflow-y-auto"
    >
      <.feed_card
        :for={{dom_id, event_scope} <- @feed}
        id={dom_id}
        event={event_scope.event}
        created_at={event_scope.created_at}
        locale={@current_user.settings.locale}
      />
      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="content-activity-feed-load-more"
        event="load_activity_feed_page"
        target={@myself}
      />
    </.stack>
    """
  end

  attr :id, :string, required: true
  attr :created_at, DateTime, required: true
  attr :event, :any, required: true
  attr :locale, :atom, required: true

  defp feed_card(%{event: %ContentAddedEvent{}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} icon={:plus} locale={@locale} created_at={@created_at}>
      <span class="text-sm text-text-muted leading-snug">
        {raw(
          dgettext("feed", "%{user} added %{content} to %{library}",
            user: gtcomponent(user_ref(%{user: @event.actor})),
            content: gtcomponent(content_link(%{content: @event.library_item.content})),
            library: gtcomponent(library_ref(%{library: @event.library_item.library}))
          )
        )}
      </span>
    </.generic_feed_card>
    """
  end

  defp feed_card(%{event: %ContentWatchedEvent{}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} icon={:circle_play} locale={@locale} created_at={@created_at}>
      <span class="text-sm text-text-muted leading-snug">
        <%= if @event.completed do %>
          {raw(
            dgettext("feed", "%{user} watched %{content}",
              user: gtcomponent(user_ref(%{user: @event.actor})),
              content: gtcomponent(content_link(%{content: @event.content}))
            )
          )}
        <% else %>
          {raw(
            dgettext("feed", "%{user} is watching %{content}",
              user: gtcomponent(user_ref(%{user: @event.actor})),
              content: gtcomponent(content_link(%{content: @event.content}))
            )
          )}
        <% end %>
      </span>
    </.generic_feed_card>
    """
  end

  attr :id, :string, required: true
  attr :icon, :atom, required: true
  attr :locale, :atom, required: true
  attr :created_at, DateTime, required: true
  slot :inner_block, required: true

  defp generic_feed_card(assigns) do
    ~H"""
    <li id={@id} class="flex gap-related [&:last-child_.rail]:hidden">
      <%!-- left rail column with event type icon --%>
      <div class="flex flex-col items-center">
        <.lucide_icon name={@icon} class="text-text-muted" />
        <span class="rail w-px flex-1 bg-border-subtle mt-tight" aria-hidden="true"></span>
      </div>

      <%!-- body — its padding sets the row height the line fills --%>
      <div class="min-w-0 pb-cluster">
        <span class="text-sm text-text-muted leading-snug">
          {render_slot(@inner_block)}
        </span>
        <time class="block text-xs text-text-subtle mt-[2px]">
          {Time.relative_from_now(@created_at, @locale)}
        </time>
      </div>
    </li>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> reset_modals()
     |> stream_configure(:feed, dom_id: &"feed-#{&1.event.id}")}
  end

  @impl true
  # Close the Add to library modal
  def update(%{close_add_to_library_modal: true}, socket) do
    {:ok, socket |> reset_modals()}
  end

  # The content has been added or removed to a club, refresh the clubs
  def update(%{refresh_clubs: true}, socket) do
    # Switch selected club with the current club to select a club if nil before
    {:ok, socket |> load_clubs() |> switch_selected_club(socket.assigns.selected_club_id)}
  end

  # An event has been created or updated from the content's activity feed
  def update(%{feed_event_upserted: %FeedEventScope{} = event}, socket) do
    # Prepend or update the event from the feed, only if it's relevant to the selected club
    if event.scope_club_id == socket.assigns.selected_club_id do
      event =
        event
        |> Ash.load!(LoadActivityFeedEvent.load_statement(), actor: socket.assigns.current_user)

      {:ok, socket |> stream_insert(:feed, event, at: 0)}
    else
      {:ok, socket}
    end
  end

  # The parent is re-rendering the component
  # This happens when the selected club has changed in the URL for example.
  def update(assigns, socket) when assigns.content_identity == socket.assigns.content_identity do
    {:ok, socket |> switch_selected_club(assigns.selected_club_id)}
  end

  # The initial update, load everything
  # The section is only displayed on detail pages when there is a single content
  # so no need to support update_many
  def update(assigns, socket) do
    {:ok,
     socket |> assign(assigns) |> load_clubs() |> switch_selected_club(assigns.selected_club_id)}
  end

  @impl true
  def handle_event("open_add_to_library_modal", _params, socket) do
    {:noreply, socket |> assign(add_to_library_modal_open: true)}
  end

  defp load_clubs(socket) do
    clubs =
      [socket.assigns.content_identity]
      |> Clubs.get_library_items_by_identities!(
        load: [library: [:club]],
        actor: socket.assigns.current_user
      )
      |> Enum.map(& &1.library.club)
      |> Enum.uniq()

    socket |> assign(clubs: clubs)
  end

  defp reset_modals(socket) do
    socket |> assign(add_to_library_modal_open: false)
  end

  # Switches to a specific club_id
  # If the club id is nil, it will use the default one (first club)
  defp switch_selected_club(socket, club_id) do
    valid_club_ids = socket.assigns.clubs |> Enum.map(& &1.id)

    selected_club_id =
      case {club_id, valid_club_ids} do
        # When the user is not in any clubs, nil
        {_, []} ->
          nil

        # When no selected club, select the first one
        {nil, [first_id | _]} ->
          first_id

        # Select the desired club if valid, otherwise select the first one
        {selected_club_id, valid_club_ids} ->
          (selected_club_id in valid_club_ids && selected_club_id) ||
            List.first(valid_club_ids)
      end

    socket
    |> assign(selected_club_id: selected_club_id)
    # Reset the stream
    |> assign(stream_state: KeysetStreamState.init(@feed_page_size))
    |> load_feed_page()
  end

  defp load_feed_page(socket) do
    case socket.assigns.selected_club_id do
      nil ->
        socket

      club_id ->
        stream_state = socket.assigns[:stream_state] || KeysetStreamState.init(@feed_page_size)

        {:ok, new_state, items} =
          KeysetStreamState.load_page(stream_state, fn page_options ->
            ActivityFeed.get_content_activity_feed(
              socket.assigns.content_identity,
              %{club_id: club_id},
              actor: socket.assigns.current_user,
              page: page_options
            )
          end)

        socket
        |> assign(:stream_state, new_state)
        |> stream(:feed, items, reset: stream_state.status == :init)
    end
  end
end
