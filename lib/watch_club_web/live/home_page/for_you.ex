defmodule WatchClubWeb.HomePage.ForYou do
  @moduledoc """
  For You on Home: what the navigation's badges count, one card each. The unread Conversations,
  then the Ready Unseen Content Requests, then the Shared Unseen Playlists.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Accounts.UserAvatar, only: [username: 1]
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Conversations.RecommendationText
  import WatchClubWeb.Components.Playlists.PlaylistLink, only: [content_counts: 1]

  alias WatchClub.Conversations.Conversation

  @doc "What to load on the Conversations, Content Requests and Playlists"
  def conversation_load, do: [last_message: [:author], content: [:implementation]]
  def request_load, do: [content: [:implementation, :added_to_library_at]]
  def playlist_load, do: [:owner, :movie_count, :tv_show_count]

  @doc "The DOM id of an item's card, for the stream"
  def dom_id(%Conversation{id: id}), do: "for-you-conversation-#{id}"
  def dom_id(%ContentRequest{id: id}), do: "for-you-request-#{id}"
  def dom_id(%Playlist{id: id}), do: "for-you-playlist-#{id}"

  attr :stream, :list,
    required: true,
    doc: "Conversations, Content Requests and Playlists, with what their `*_load/0` say loaded"

  attr :locale, :atom, required: true

  # Hidden while the stream is empty
  def for_you(assigns) do
    ~H"""
    <.page_section
      id="for-you-title"
      title={dgettext("home", "For you")}
      class="not-has-[[data-for-you-item]]:hidden"
    >
      <.scroll_row id="for-you" stream>
        <.for_you_card :for={{dom_id, item} <- @stream} id={dom_id} item={item} locale={@locale} />
      </.scroll_row>
    </.page_section>
    """
  end

  attr :id, :string, required: true
  attr :item, :any, required: true
  attr :locale, :atom, required: true

  defp for_you_card(%{item: %Conversation{} = conversation} = assigns) do
    assigns = assign(assigns, :message, conversation.last_message)

    ~H"""
    <.card_frame
      id={@id}
      navigate={~p"/inbox/#{@item.id}"}
      title={@item.content.implementation.best_localization.title}
    >
      <:artwork>
        <.tmdb_poster path={@item.content.implementation.best_localization.poster_path} size="w185" />
      </:artwork>
      <:reason>
        <Lucideicons.message_circle class="size-icon-sm shrink-0" />
        <span class="truncate">
          {dgettext("home", "From %{user}", user: username(@message.author))}
        </span>
      </:reason>
      <.recommendation_text
        :if={@message.body}
        body={@message.body}
        class="line-clamp-2 text-sm text-text-muted"
      />
    </.card_frame>
    """
  end

  defp for_you_card(%{item: %ContentRequest{}} = assigns) do
    ~H"""
    <.card_frame
      id={@id}
      navigate={Url.content_details_link(@item.content)}
      title={@item.content.implementation.best_localization.title}
    >
      <:artwork>
        <.tmdb_poster path={@item.content.implementation.best_localization.poster_path} size="w185" />
      </:artwork>
      <:reason>
        <Lucideicons.circle_check class="size-icon-sm shrink-0" />
        <span class="truncate">{dgettext("home", "Ready to watch")}</span>
      </:reason>
      <%!-- Nil once its last Media is gone --%>
      <time
        :if={@item.content.added_to_library_at}
        datetime={DateTime.to_iso8601(@item.content.added_to_library_at)}
        class="text-sm text-text-subtle"
      >
        {Time.relative_from_now(@item.content.added_to_library_at, @locale)}
      </time>
    </.card_frame>
    """
  end

  defp for_you_card(%{item: %Playlist{}} = assigns) do
    ~H"""
    <.card_frame
      id={@id}
      navigate={~p"/playlists/#{@item.id}"}
      title={@item.name}
    >
      <:artwork>
        <div class="flex aspect-2/3 items-center justify-center rounded-lg bg-surface-raised">
          <.lucide_icon name={@item.icon} class="size-icon-lg text-text-muted" />
        </div>
      </:artwork>
      <:reason>
        <Lucideicons.list class="size-icon-sm shrink-0" />
        <span class="truncate">
          {dgettext("home", "Shared by %{user}", user: @item.owner.username)}
        </span>
      </:reason>
      <p class="text-sm text-text-muted">{content_counts(@item)}</p>
    </.card_frame>
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, required: true
  attr :title, :string, required: true
  slot :artwork, required: true, doc: "a poster, or what stands for one"
  slot :reason, required: true, doc: "why it's for the User, with an icon"
  slot :inner_block, required: true, doc: "what it says under its title"

  # The whole card is the title link, stretched with ::after, which describes it with why it's
  # for the User. That reason comes first visually, but after the title for screen readers.
  defp card_frame(assigns) do
    ~H"""
    <.card
      as="article"
      padding="related"
      id={@id}
      data-for-you-item
      class="relative flex w-72 min-w-0 shrink-0 snap-start gap-group has-focus-visible:outline-2 has-focus-visible:outline-offset-2"
    >
      <div aria-hidden="true" class="w-16 shrink-0 self-start @xl:w-20">
        {render_slot(@artwork)}
      </div>
      <div class="flex min-w-0 flex-1 flex-col gap-related py-tight">
        <.link
          navigate={@navigate}
          aria-describedby={"#{@id}-reason"}
          class="min-w-0 truncate font-semibold text-text outline-none after:absolute after:inset-0"
        >
          {@title}
        </.link>
        <p
          id={"#{@id}-reason"}
          class="-order-1 flex items-center gap-tight text-sm font-semibold text-accent"
        >
          {render_slot(@reason)}
        </p>
        {render_slot(@inner_block)}
      </div>
    </.card>
    """
  end
end
