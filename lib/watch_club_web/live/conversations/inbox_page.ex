defmodule WatchClubWeb.Conversations.InboxPage do
  @moduledoc """
  The Inbox: the User's Conversations, the one with the latest Message first, beside the one that's
  open. Narrow screens show the list or the open Conversation, which fills the screen on phones.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Accounts.UserAvatar
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias Ash.Notifier.Notification
  alias WatchClub.Conversations
  alias WatchClub.Conversations.{Conversation, Message, Participant}
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive
  alias WatchClubWeb.Conversations.InboxPage.ConversationLive

  # What a row shows
  @row_load [
    :last_message_at,
    :recommended_by,
    :recipients,
    last_message: [:author],
    actor_participant: [:unread_count],
    content: [:implementation]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      title={dgettext("nav", "Inbox")}
      full_screen?={@conversation != nil}
      space="none"
      class="p-0!"
    >
      <%!-- Narrow screens show the list or the open Conversation, wide ones both, each scrolling on
      its own under the bar --%>
      <div class={[
        "@container flex md:h-[calc(100svh-var(--wc-app-bar-height))]",
        @conversation && "max-md:h-svh"
      ]}>
        <aside
          aria-label={dgettext("conversations", "Conversations")}
          class={[
            "w-full flex-col pb-group [scrollbar-color:var(--color-surface-hover)_transparent] [scrollbar-width:thin] md:overflow-y-auto md:pt-group @4xl:flex @4xl:w-96 @4xl:shrink-0 @4xl:border-r @4xl:border-border-subtle",
            @conversation && "hidden",
            !@conversation && "flex"
          ]}
        >
          <ul id="conversations" phx-update="stream" class="flex flex-col gap-px px-related">
            <li :for={{dom_id, conversation} <- @streams.conversations} id={dom_id}>
              <.conversation_row
                conversation={conversation}
                current_user={@current_user}
                time_zone={@time_zone}
                selected={@conversation != nil and @conversation.id == conversation.id}
              />
            </li>
            <li id="conversations-empty" class="hidden px-related only:block">
              <.empty size="sm">
                <:icon><Lucideicons.inbox /></:icon>
                <:title>{dgettext("conversations", "No conversations yet")}</:title>
                <:description>
                  {dgettext(
                    "conversations",
                    "Recommend a movie or a TV show from its page to start one."
                  )}
                </:description>
              </.empty>
            </li>
          </ul>
        </aside>

        <div class={[
          "min-w-0 flex-1 flex-col md:overflow-y-auto @4xl:flex",
          @conversation && "flex",
          !@conversation && "hidden"
        ]}>
          <.live_component
            :if={@conversation}
            id={ConversationLive.dom_id()}
            module={ConversationLive}
            conversation={@conversation}
            current_user={@current_user}
            time_zone={@time_zone}
          />
          <div :if={!@conversation} class="px-page pb-page-y md:pt-group">
            <.empty>
              <:icon><Lucideicons.messages_square /></:icon>
              <:title>{dgettext("conversations", "No conversation open")}</:title>
              <:description>
                {dgettext("conversations", "Pick one in the list to read it.")}
              </:description>
            </.empty>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :conversation, Conversation, required: true
  attr :current_user, User, required: true
  attr :time_zone, :string, required: true
  attr :selected, :boolean, required: true

  # The Content's poster with the recommender's avatar, its name and when the latest Message came,
  # then that Message and how many the User hasn't read
  defp conversation_row(assigns) do
    %{conversation: conversation, current_user: user} = assigns

    assigns =
      assign(assigns,
        title: conversation.content.implementation.best_localization.title,
        unread_count: conversation.actor_participant.unread_count,
        others: Enum.count(conversation.recipients, &(&1.user_id != user.id)),
        group?: length(conversation.recipients) > 1
      )

    ~H"""
    <.link
      id={"conversation-#{@conversation.id}-link"}
      patch={~p"/inbox/#{@conversation.id}"}
      aria-current={@selected && "true"}
      class="flex items-center gap-group rounded-control p-related transition-colors hover:bg-surface-hover aria-[current=true]:bg-surface-selected"
    >
      <div class="relative shrink-0">
        <.tmdb_poster
          path={@conversation.content.implementation.best_localization.poster_path}
          size="w154"
          class="w-12"
        />
        <div class="absolute -right-tight -bottom-related">
          <.user_avatar user={@conversation.recommended_by} class="ring-2 ring-canvas" />
          <span
            :if={@group?}
            aria-label={
              dngettext("conversations", "and %{count} other", "and %{count} others", @others)
            }
            class="absolute top-1/2 left-full -ml-2.5 grid size-5 -translate-y-1/2 place-items-center rounded-full border border-border bg-surface-raised text-xs font-semibold text-text ring-2 ring-canvas"
          >
            +{@others}
          </span>
        </div>
      </div>
      <div class="flex min-w-0 flex-1 flex-col gap-tight">
        <div class="flex items-baseline gap-related">
          <span class="min-w-0 flex-1 truncate font-semibold">{@title}</span>
          <span class={[
            "shrink-0 text-xs",
            @unread_count > 0 && "font-semibold text-accent",
            @unread_count == 0 && "text-text-subtle"
          ]}>
            {Time.clock_or_day(
              @conversation.last_message_at,
              @time_zone,
              @current_user.settings.locale
            )}
          </span>
        </div>
        <div class="flex items-center gap-related">
          <.last_message
            message={@conversation.last_message}
            current_user={@current_user}
            group?={@group?}
          />
          <.unread_badge count={@unread_count} />
        </div>
      </div>
    </.link>
    """
  end

  attr :message, Message, required: true
  attr :current_user, User, required: true
  attr :group?, :boolean, required: true

  # The latest Message, after "You:" on the User's own, or who wrote it in a group
  defp last_message(assigns) do
    ~H"""
    <span class="min-w-0 flex-1 truncate text-sm text-text-muted">
      <%= cond do %>
        <% @message.author_id == @current_user.id -> %>
          {dgettext("conversations", "You: %{text}", text: text(@message))}
        <% @group? -> %>
          {dgettext("conversations", "%{name}: %{text}",
            name: username(@message.author),
            text: text(@message)
          )}
        <% true -> %>
          {text(@message)}
      <% end %>
    </span>
    """
  end

  defp text(%Message{kind: :recommendation, body: nil}),
    do: dgettext("conversations", "Recommended it")

  defp text(%Message{body: body}), do: body

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> WatchClub.PubSub.subscribe_to_current_user_content_topics()
     |> stream_configure(:conversations, dom_id: &"conversation-#{&1.id}")
     |> stream(
       :conversations,
       Conversations.list_conversations!(load: @row_load, actor: socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _uri, socket) do
    case Conversations.get_conversation(id,
           load: ConversationLive.conversation_load(),
           actor: socket.assigns.current_user
         ) do
      {:ok, conversation} ->
        {:noreply, assign(socket, :conversation, conversation)}

      {:error, _not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("conversations", "This conversation doesn't exist"))
         |> push_patch(to: ~p"/inbox")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, assign(socket, :conversation, nil)}

  @impl true
  def handle_info(%Notification{} = notification, socket) do
    PlayOrRequestButtonLive.handle_pubsub_message(
      notification,
      socket.assigns.current_user,
      ConversationLive.play_placements()
    )

    case notification do
      # A new Conversation, or a new Message in one: it goes first
      %{resource: Participant, action: %{name: :create}, data: participant} ->
        {:noreply, put_first(socket, participant.conversation_id)}

      %{resource: Message, data: message} ->
        if socket.assigns.conversation, do: ConversationLive.show_message(message)
        {:noreply, put_first(socket, message.conversation_id)}

      # The User read it, maybe in another tab
      %{resource: Participant, action: %{name: :mark_read}, data: participant} ->
        {:noreply,
         stream_insert(socket, :conversations, get_row!(socket, participant.conversation_id))}

      _other ->
        {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp put_first(socket, conversation_id) do
    conversation = get_row!(socket, conversation_id)

    socket
    |> stream_delete(:conversations, conversation)
    |> stream_insert(:conversations, conversation, at: 0)
  end

  defp get_row!(socket, conversation_id) do
    Conversations.get_conversation!(conversation_id,
      load: @row_load,
      actor: socket.assigns.current_user
    )
  end
end
