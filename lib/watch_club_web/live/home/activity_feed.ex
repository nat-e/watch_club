defmodule WatchClubWeb.Live.Home.ActivityFeed do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Helpers.KeysetStreamState

  attr :stream, :list, required: true
  attr :stream_state, KeysetStreamState, required: true
  attr :current_user, User, required: true

  def activity_feed(assigns) do
    ~H"""
    <.section
      surface="transparent"
      title="Recent Activity"
      space="related"
      padding="tight"
    >
      <.stack space="related" id="activity-feed" phx-update="stream">
        <div class="only:block hidden">
          <.empty_feed current_user={@current_user} />
        </div>
        <.feed_card
          :for={{dom_id, event} <- @stream}
          id={dom_id}
          event={event}
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

  # The feed can be empty for the administrator when they just created the instance
  # Use this as an onboarding screen for prompting them to create a Club
  # We already have the entire club creation flow handled in the sidebar, so we just
  # send the event to that LiveView
  def empty_feed(%{current_user: %User{administrator?: true}} = assigns) do
    ~H"""
    <.empty>
      <:icon><Lucideicons.rocket /></:icon>
      <:title>Welcome to Watch Club!</:title>
      <:description>
        Your instance is successfully installed!
        <br />Create a club and invite your friends to get started
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
      <:title>Welcome to Watch Club!</:title>
      <:description>
        It's more fun with friends, contact the administrator so they can add you to some Clubs.<br />In the mean time, you can still browse and watch some content on your own.
      </:description>
    </.empty>
    """
  end

  attr :id, :string, required: true
  attr :event, Event, required: true
  attr :locale, :atom, required: true

  def feed_card(%{event: %Event{type: :club_created}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} event={@event} locale={@locale}>
      <span class="text-sm">
        <.user_ref user={@event.actor} /> created the club
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %Event{type: :library_created}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} event={@event} locale={@locale}>
      <span class="text-sm">
        <.user_ref user={@event.actor} /> created the library
        <.library_ref library={@event.library_created.library} />
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %Event{type: :content_added}} = assigns) do
    ~H"""
    <.generic_feed_card
      id={@id}
      event={@event}
      locale={@locale}
      content={@event.content_added.library_item.content}
    >
      <span class="text-sm">
        <.user_ref user={@event.actor} /> added
        <.content_link content={@event.content_added.library_item.content} /> to
        <.library_ref library={@event.content_added.library_item.library} />
      </span>
    </.generic_feed_card>
    """
  end

  def feed_card(%{event: %Event{type: :member_added}} = assigns) do
    ~H"""
    <.generic_feed_card id={@id} event={@event} locale={@locale}>
      <span class="text-sm">
        <.user_ref user={@event.member_added.membership.user} /> joined the club
      </span>
    </.generic_feed_card>
    """
  end

  attr :id, :string, required: true
  attr :event, Event, required: true
  attr :locale, :atom, required: true
  attr :content, Content, default: nil

  slot :inner_block

  def generic_feed_card(assigns) do
    ~H"""
    <.card id={@id}>
      <.inline space="group" class="items-start h-full">
        <.stack space="group" class="flex-1 h-full">
          <.club_ref club={@event.scope_club} />
          <div class="flex-1">{render_slot(@inner_block)}</div>
          <span class="text-sm text-text-subtle">
            {Time.relative_from_now(@event.created_at, @locale)}
          </span>
        </.stack>
        <.link :if={@content} patch={Url.content_details_link(@content)}>
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
