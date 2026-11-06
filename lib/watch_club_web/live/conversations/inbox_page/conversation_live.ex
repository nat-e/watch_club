defmodule WatchClubWeb.Conversations.InboxPage.ConversationLive do
  @moduledoc """
  The open Conversation. First, on the dimmed wide image: who recommended the Content to whom, its
  name, the recommendation's text and Play, or Request while it's missing from the Library. Once
  Play scrolls away, a bar keeps the poster, the name and Play. Then the Messages, with a line where
  the User's unread ones start, and the field to post one.

  Opening it, and each Message that arrives while it's open, marks it read.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Accounts.UserAvatar
  import WatchClubWeb.Components.Contents.TmdbBackdrop
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Conversations.{Recipients, RecommendationNote}
  import WatchClubWeb.Helpers.ContentDetails

  alias WatchClub.{Contents, Conversations}
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Conversations.{Conversation, Message}
  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive

  @doc """
  What the open Conversation needs loaded on the `conversation` it's given.
  """
  def conversation_load do
    [
      :recommendation,
      :recommended_by,
      recipients: [:user],
      actor_participant: [:unread_count],
      content: [:implementation]
    ]
  end

  def dom_id, do: "conversation"

  @doc """
  The placements of its Play or Request buttons, to keep them up to date.
  """
  def play_placements, do: [nil, :compact]

  @doc """
  Shows a Message posted in the open Conversation.
  """
  def show_message(%Message{} = message),
    do: send_update(__MODULE__, id: dom_id(), posted: message)

  attr :conversation, Conversation, required: true, doc: "with `conversation_load/0`"
  attr :current_user, User, required: true
  attr :time_zone, :string, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <section
      id={"#{@id}-panel"}
      aria-label={dgettext("conversations", "Conversation about %{title}", title: title(@details))}
      phx-mounted={JS.ignore_attributes(["data-collapsed"])}
      class="group/conversation relative flex min-h-0 min-w-0 flex-1 flex-col"
    >
      <.compact_bar
        conversation={@conversation}
        details={@details}
        identity={@identity}
        current_user={@current_user}
      />

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Messages">
        export default {
          mounted() {
            this.last = this.el.dataset.last
            const unread = this.el.querySelector("[data-unread]")
            this.el.scrollTop = unread ? unread.offsetTop - 8 : this.el.scrollHeight
            this.observePlay()
          },
          updated() {
            this.observePlay()
            // A new Message: show it
            if (this.el.dataset.last === this.last) return
            this.last = this.el.dataset.last
            this.el.scrollTop = this.el.scrollHeight
          },
          destroyed() {
            this.observer?.disconnect()
          },
          // The bar shows once the header's Play scrolls away
          observePlay() {
            const play = this.el.querySelector("[data-hero-play]")
            const section = this.el.closest("section")
            if (play === this.play) return
            this.observer?.disconnect()
            this.play = play
            section.removeAttribute("data-collapsed")
            if (!play) return
            this.observer = new IntersectionObserver(([entry]) => {
              entry.isIntersecting ? section.removeAttribute("data-collapsed") : section.setAttribute("data-collapsed", "")
            }, {root: this.el})
            this.observer.observe(play)
          }
        }
      </script>
      <div
        id={"#{@id}-messages"}
        phx-hook=".Messages"
        data-last={@last_message && @last_message.id}
        role="log"
        class="relative flex min-h-0 flex-1 flex-col overflow-y-auto px-page pt-related pb-group [scrollbar-color:var(--color-surface-hover)_transparent] [scrollbar-width:thin] *:shrink-0 @4xl:px-cluster"
      >
        <.hero
          conversation={@conversation}
          details={@details}
          identity={@identity}
          current_user={@current_user}
          unread?={@recommendation_unread?}
        />
        <div id={"#{@id}-stream"} phx-update="stream" class="flex flex-col">
          <div :for={{dom_id, item} <- @streams.messages} id={dom_id} class="flex flex-col">
            <.badge
              :if={item.day}
              variant="secondary"
              size="sm"
              class="sticky top-related z-10 my-related self-center"
            >
              {item.day}
            </.badge>
            <p
              :if={item.unread_count}
              data-unread
              class="-mx-page my-related bg-surface-raised py-tight text-center text-xs font-semibold text-text-muted @4xl:-mx-cluster"
            >
              {dngettext(
                "conversations",
                "%{count} unread message",
                "%{count} unread messages",
                item.unread_count
              )}
            </p>
            <.message
              message={item.message}
              first?={item.first?}
              group?={@group?}
              current_user={@current_user}
              time_zone={@time_zone}
            />
          </div>
        </div>
      </div>

      <div class="border-t border-border-subtle px-page py-related @4xl:px-cluster">
        <.form
          for={@form}
          id={"#{@id}-composer"}
          phx-submit="post"
          phx-target={@myself}
          layout="none"
          class="flex items-start gap-related"
        >
          <div class="flex min-w-0 flex-1 flex-col gap-tight">
            <label for={"#{@id}-body"} class="sr-only">{dgettext("conversations", "Message")}</label>
            <.input
              id={"#{@id}-body"}
              name={@form[:body].name}
              value={@form[:body].value}
              autocomplete="off"
              placeholder={dgettext("conversations", "Message…")}
              phx-patch-focused
              class="h-control-lg!"
            />
            <.field_errors field={@form[:body]} role="alert" class="text-xs" />
          </div>
          <.button
            id={"#{@id}-send"}
            type="submit"
            variant="accent"
            size="icon-lg"
            aria-label={dgettext("conversations", "Send")}
            title={dgettext("conversations", "Send")}
          >
            <Lucideicons.send_horizontal />
          </.button>
        </.form>
      </div>
    </section>
    """
  end

  attr :conversation, Conversation, required: true
  attr :details, :any, required: true, doc: "a `MovieDetailsResponse` or a `TvDetailsResponse`"
  attr :identity, ContentIdentity, required: true
  attr :current_user, User, required: true
  attr :unread?, :boolean, required: true, doc: "whether the User hasn't read the recommendation"

  # On the dimmed wide image, centered: who recommended it to whom, the Content's name, the
  # recommendation's text as a big quote, then Play
  defp hero(assigns) do
    ~H"""
    <div
      data-unread={@unread?}
      class="relative isolate -mx-page -mt-related overflow-hidden @4xl:-mx-cluster"
    >
      <.tmdb_backdrop
        :if={@details.backdrop_path}
        path={@details.backdrop_path}
        size="w1280"
        class="absolute inset-0 -z-10 size-full object-cover"
      />
      <span class="absolute inset-0 -z-10 bg-canvas/80"></span>
      <div class="flex flex-col items-center gap-group px-page pt-related pb-group text-center @4xl:px-cluster @4xl:pt-cluster">
        <%!-- Phones hide the bar, which has back elsewhere --%>
        <.button
          id="conversation-back"
          variant="ghost"
          size="icon"
          patch={~p"/inbox"}
          aria-label={dgettext("conversations", "Back to Inbox")}
          title={dgettext("conversations", "Back to Inbox")}
          class="-ml-related self-start text-text! rounded-full! pointer-coarse:size-touch-target! md:hidden"
        >
          <Lucideicons.arrow_left />
        </.button>
        <div class="min-w-0 text-sm text-text-muted">
          {recommended_it(assigns)}
          <span class="ml-related inline-flex items-center gap-tight align-middle text-xs text-text-subtle">
            {Time.relative_from_now(
              @conversation.recommendation.inserted_at,
              @current_user.settings.locale
            )}
            <.badge :if={@unread?} variant="accent" size="sm">
              {dgettext("conversations", "New")}
            </.badge>
          </span>
        </div>
        <div class="flex flex-col">
          <h2 class="font-heading text-2xl font-semibold text-balance @3xl:text-3xl">
            <.link navigate={Url.content_details_link(@identity)} class="hover:underline">
              {title(@details)}
            </.link>
          </h2>
          <span class="text-sm text-text-muted">
            {facts(@details, @identity, @current_user.settings.locale)}
          </span>
        </div>
        <.recommendation_note
          :if={@conversation.recommendation.body}
          body={@conversation.recommendation.body}
          class="max-w-readable text-lg"
        />
        <span data-hero-play>
          <.live_component
            id={PlayOrRequestButtonLive.dom_id(@identity)}
            module={PlayOrRequestButtonLive}
            content_identity={@identity}
            current_user={@current_user}
            size="lg"
          />
        </span>
      </div>
    </div>
    """
  end

  attr :conversation, Conversation, required: true
  attr :details, :any, required: true
  attr :identity, ContentIdentity, required: true
  attr :current_user, User, required: true

  # Once the header's Play scrolls away: the poster, the name, who recommended it and Play
  defp compact_bar(assigns) do
    ~H"""
    <div class="absolute inset-x-0 top-0 z-20 hidden items-center gap-group border-b border-border-subtle bg-canvas px-page py-related group-data-collapsed/conversation:flex @4xl:px-cluster">
      <.button
        id="compact-back"
        patch={~p"/inbox"}
        variant="ghost"
        size="icon"
        aria-label={dgettext("conversations", "Back to Inbox")}
        title={dgettext("conversations", "Back to Inbox")}
        class="-ml-related text-text! rounded-full! pointer-coarse:size-touch-target! md:hidden"
      >
        <Lucideicons.arrow_left />
      </.button>
      <.tmdb_poster path={@details.poster_path} size="w154" class="w-10 shrink-0" />
      <div class="flex min-w-0 flex-1 flex-col">
        <.link
          navigate={Url.content_details_link(@identity)}
          class="truncate font-semibold hover:underline"
        >
          {title(@details)}
        </.link>
        <span class="truncate text-xs text-text-muted">
          {recommended_by(@conversation, @current_user)}
        </span>
      </div>
      <%!-- Only its icon: a label would squeeze the name --%>
      <.live_component
        id={PlayOrRequestButtonLive.dom_id(@identity, :compact)}
        module={PlayOrRequestButtonLive}
        content_identity={@identity}
        current_user={@current_user}
        variant="round"
      />
    </div>
    """
  end

  attr :message, Message, required: true
  attr :first?, :boolean, required: true, doc: "whether it starts a run of Messages by one User"
  attr :group?, :boolean, required: true
  attr :current_user, User, required: true
  attr :time_zone, :string, required: true

  # A bubble with the time inside. In a group, the first of a run has the avatar and the name.
  defp message(assigns) do
    assigns = assign(assigns, :mine?, assigns.message.author_id == assigns.current_user.id)

    ~H"""
    <div class={[
      "flex items-start gap-related",
      @mine? && "justify-end",
      @first? && "mt-group",
      !@first? && "mt-tight"
    ]}>
      <div :if={@group? and !@mine?} class="w-7 shrink-0">
        <.user_avatar :if={@first?} user={@message.author} />
      </div>
      <div class={[
        "relative max-w-readable min-w-0 rounded-control px-related py-tight text-sm text-text",
        @mine? && "bg-accent-bg",
        !@mine? && "bg-surface-raised"
      ]}>
        <span
          :if={@group? and @first? and !@mine?}
          class="block text-xs font-semibold text-text-muted"
        >
          {username(@message.author)}
        </span>
        <span class="break-words whitespace-pre-line">{@message.body}</span>
        <%!-- Room for the time on the last line --%>
        <span class="inline-block w-12"></span>
        <span class="absolute right-related bottom-tight text-xs text-text-subtle">
          {Time.clock(@message.inserted_at, @time_zone, @current_user.settings.locale)}
        </span>
      </div>
    </div>
    """
  end

  # "[avatar] bastou recommended it to [avatars] you, leadelpeut and vinz"
  defp recommended_it(assigns) do
    %{conversation: conversation, current_user: user} = assigns

    recipients =
      gtcomponent(~H"""
      <.recipients conversation={@conversation} current_user={@current_user} class="ml-tight" />
      """)

    if conversation.recommended_by_id == user.id do
      raw(
        dgettext("conversations", "You recommended it to %{recipients}", recipients: recipients)
      )
    else
      recommender =
        gtcomponent(~H"""
        <span class="inline-flex items-center gap-tight align-middle">
          <.user_avatar user={@conversation.recommended_by} size="sm" />
          <span class="font-semibold text-text">{username(@conversation.recommended_by)}</span>
        </span>
        """)

      raw(
        dgettext("conversations", "%{recommender} recommended it to %{recipients}",
          recommender: recommender,
          recipients: recipients
        )
      )
    end
  end

  defp recommended_by(%Conversation{recommended_by_id: id}, %User{id: id}),
    do: dgettext("conversations", "Recommended by you")

  defp recommended_by(conversation, _user),
    do:
      dgettext("conversations", "Recommended by %{name}",
        name: username(conversation.recommended_by)
      )

  # "2022 · Movie · 2 hr 9 min"
  defp facts(details, identity, locale) do
    [
      Time.maybe_year(release_date(details)),
      ContentType.translated_label(identity.type),
      length_label(details, locale)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  @impl true
  def update(%{posted: %Message{} = message}, socket) do
    %{conversation: conversation, current_user: user} = socket.assigns

    if message.conversation_id == conversation.id do
      message = Conversations.get_message!(message.id, load: [:author], actor: user)
      if message.author_id != user.id, do: mark_read!(socket)

      {:ok,
       socket
       |> stream_insert(:messages, item(message, socket.assigns.last_message, nil, socket))
       |> assign(:last_message, message)}
    else
      {:ok, socket}
    end
  end

  def update(assigns, socket) do
    opened? = socket.assigns[:conversation] && socket.assigns.conversation.id

    socket = assign(socket, assigns)

    if opened? == assigns.conversation.id,
      do: {:ok, socket},
      else: {:ok, open(socket)}
  end

  # The Messages, the line where the unread ones start, and the composer. The unread Messages are
  # the latest ones, after the User's read position: the recommendation, then the others.
  defp open(socket) do
    %{conversation: conversation, current_user: user} = socket.assigns

    messages =
      conversation.id
      |> Conversations.list_messages!(load: [:author], actor: user)
      |> Enum.filter(&(&1.kind == :text))

    unread_count = conversation.actor_participant.unread_count
    unread_messages = min(unread_count, length(messages))
    first_unread = length(messages) - unread_messages

    {items, _last} =
      messages
      |> Enum.with_index()
      |> Enum.map_reduce(nil, fn {message, index}, previous ->
        unread = if index == first_unread and unread_messages > 0, do: unread_messages
        {item(message, previous, unread, socket), message}
      end)

    if unread_count > 0, do: mark_read!(socket)

    socket
    |> assign(
      details: details!(conversation.content, user),
      identity: ContentIdentity.from_content(conversation.content),
      group?: length(conversation.recipients) > 1,
      recommendation_unread?: unread_count > length(messages),
      last_message: List.last(messages),
      form: new_form(socket)
    )
    |> stream(:messages, items, reset: true)
  end

  # A Message with the lines before it: its day when it changes, and where the unread ones start.
  # It starts a run unless it follows one by the same User with no line between them.
  defp item(message, previous, unread_count, socket) do
    %{time_zone: time_zone, current_user: user} = socket.assigns

    day =
      if previous == nil or
           Time.local_date(previous.inserted_at, time_zone) !=
             Time.local_date(message.inserted_at, time_zone),
         do: Time.day(message.inserted_at, time_zone, user.settings.locale)

    %{
      id: message.id,
      message: message,
      day: day,
      unread_count: unread_count,
      first?:
        previous == nil or previous.author_id != message.author_id or day != nil or
          unread_count != nil
    }
  end

  # Only once connected: the first, static render would mark it read before it shows
  defp mark_read!(socket) do
    if connected?(socket) do
      %{conversation: conversation, current_user: user} = socket.assigns
      Conversations.mark_conversation_read!(conversation.actor_participant, actor: user)
    end
  end

  defp details!(%Content{type: :movie, external_id: id}, user),
    do: Contents.get_movie_details!(id, actor: user)

  defp details!(%Content{type: :tv_show, external_id: id}, user),
    do: Contents.get_tv_show_details!(id, actor: user)

  defp new_form(socket) do
    %{conversation: conversation, current_user: user} = socket.assigns

    Conversations.form_to_post_message(
      actor: user,
      transform_params: fn _form, params, _type ->
        Map.put(params, "conversation_id", conversation.id)
      end
    )
    |> to_form()
  end

  @impl true
  def handle_event("post", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      # The Message shows once it comes back from PubSub, as for the other Participants
      {:ok, _message} -> {:noreply, assign(socket, :form, new_form(socket))}
      {:error, form} -> {:noreply, assign(socket, :form, form)}
    end
  end
end
