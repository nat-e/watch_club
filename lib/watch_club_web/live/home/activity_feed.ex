defmodule WatchClubWeb.Live.Home.ActivityFeed do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Helpers.KeysetStreamState

  attr :stream, :list, required: true
  attr :stream_state, KeysetStreamState, required: true
  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true

  def activity_feed(assigns) do
    ~H"""
    <.section
      surface="transparent"
      title={dgettext("feed", "Recent Activity")}
      space="related"
      padding="tight"
    >
      <.stack space="related" id="activity-feed" phx-update="stream">
        <div id="activity-feed-empty-state" class="only:block hidden">
          <.empty_feed current_user={@current_user} instance_settings={@instance_settings} />
        </div>
        <.feed_card
          :for={{dom_id, event_scope} <- @stream}
          id={dom_id}
          event={event_scope}
          locale={@current_user.settings.locale}
        />
      </.stack>

      <.infinite_scroll_trigger
        :if={KeysetStreamState.can_load_more?(@stream_state)}
        id="activity-feed-load-more"
        event="load_activity_feed_page"
      />
    </.section>
    """
  end

  attr :current_user, User, required: true
  attr :instance_settings, InstanceSettings, required: true

  # The feed can be empty for the administrator when they just created the instance
  # Use this as an onboarding screen for prompting them to create a Club
  # We already have the entire club creation flow handled in the sidebar, so we just
  # send the event to that LiveView
  def empty_feed(%{current_user: %User{administrator?: true}} = assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.rocket /></:icon>
      <:title>{dgettext("feed", "Welcome to Watch Club!")}</:title>
      <:description>
        {dgettext("feed", "Your instance is successfully installed!")}
        <br />{dgettext("feed", "Create a club and invite your friends to get started")}
      </:description>
      <.button
        id="empty-feed-create-club"
        variant="primary"
        phx-click="open_create_club_modal"
        phx-target={"##{WatchClubWeb.Components.Navigation.SidebarLive.dom_id()}"}
      >
        <:icon position="start"><Lucideicons.plus /></:icon>
        {dgettext("feed", "Create club")}
      </.button>
    </.empty>
    """
  end

  # The feed can also be empty for a user that is not a member of any club.
  def empty_feed(assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.mail /></:icon>
      <:title>{dgettext("feed", "Welcome to %{name}!", name: @instance_settings.name)}</:title>
      <:description>
        {dgettext(
          "feed",
          "It's more fun with friends, contact the administrator so they can add you to some Clubs."
        )}
        <br />
        {dgettext(
          "feed",
          "In the mean time, you can still browse and watch some content on your own."
        )}
      </:description>
    </.empty>
    """
  end

  attr :id, :string, required: true
  attr :event, FeedEventScope, required: true
  attr :locale, :atom, required: true

  def feed_card(%{event: %FeedEventScope{event: %ClubCreatedEvent{}}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} event={@event} locale={@locale}>
      <span class="text-sm">
        {raw(
          dgettext("feed", "%{user} created the club",
            user: gtcomponent(user_ref(%{user: @event.event.actor}))
          )
        )}
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %FeedEventScope{event: %LibraryCreatedEvent{}}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} event={@event} locale={@locale}>
      <span class="text-sm">
        {raw(
          dgettext("feed", "%{user} created the library %{library}",
            user: gtcomponent(user_ref(%{user: @event.event.actor})),
            library: gtcomponent(library_ref(%{library: @event.event.library}))
          )
        )}
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %FeedEventScope{event: %ContentAddedEvent{}}} = assigns) do
    ~H"""
    <.generic_feed_card
      id={@id}
      event={@event}
      locale={@locale}
      content={@event.event.library_item.content}
    >
      <span class="text-sm">
        {raw(
          dgettext("feed", "%{user} added %{content} to %{library}",
            user: gtcomponent(user_ref(%{user: @event.event.actor})),
            content: gtcomponent(content_link(%{content: @event.event.library_item.content})),
            library: gtcomponent(library_ref(%{library: @event.event.library_item.library}))
          )
        )}
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %FeedEventScope{event: %ContentWatchedEvent{}}} = assigns) do
    ~H"""
    <.generic_feed_card
      id={@id}
      event={@event}
      locale={@locale}
      content={@event.event.content}
    >
      <span class="text-sm">
        <%= if @event.event.completed do %>
          {raw(
            dgettext("feed", "%{user} watched %{content}",
              user: gtcomponent(user_ref(%{user: @event.event.actor})),
              content: gtcomponent(content_link(%{content: @event.event.content}))
            )
          )}
        <% else %>
          {raw(
            dgettext("feed", "%{user} is watching %{content}",
              user: gtcomponent(user_ref(%{user: @event.event.actor})),
              content: gtcomponent(content_link(%{content: @event.event.content}))
            )
          )}
        <% end %>
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %FeedEventScope{event: %MemberAddedEvent{}}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} event={@event} locale={@locale}>
      <span class="text-sm">
        {raw(
          dgettext("feed", "%{user} joined the club",
            user: gtcomponent(user_ref(%{user: @event.event.membership.user}))
          )
        )}
      </span>
    </.generic_feed_card>
    """
  end

  attr :id, :string, required: true
  attr :event, FeedEventScope, required: true
  attr :locale, :atom, required: true
  attr :content, Content, default: nil

  slot :inner_block

  def generic_feed_card(assigns) do
    ~H"""
    <.card id={@id}>
      <.inline space="group" class="items-start h-full">
        <.stack space="group" class="flex-1 h-full">
          <.club_ref :if={@event.scope_club} club={@event.scope_club} />
          <div class="flex-1">{render_slot(@inner_block)}</div>
          <span class="text-sm text-text-subtle">
            {Time.relative_from_now(@event.created_at, @locale)}
          </span>
        </.stack>
        <.link :if={@content} navigate={Url.content_details_link(@content)}>
          <.tmdb_poster
            size="w342"
            path={@content.implementation.best_localization.poster_path}
            class="w-24 border border-subtle"
          />
        </.link>
      </.inline>
    </.card>
    """
  end
end
