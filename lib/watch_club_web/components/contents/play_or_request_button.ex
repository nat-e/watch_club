defmodule WatchClubWeb.Components.Contents.PlayOrRequestButton do
  @moduledoc """
  Play for a Content with Media. Otherwise Request, or the status of the Content's Content
  Request, with Get Notified when the actor isn't one of its Request Subscribers.
  `PlayOrRequestButtonLive` loads what it shows, makes the request and gets the actor notified.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :has_media?, :boolean, required: true
  attr :play_href, :string, default: nil, doc: "the Player, nil when there's nothing to play"
  attr :play_label, :string, required: true, doc: "such as Play, or Resume S01E03"

  attr :title, :string,
    default: nil,
    doc: "the Content's name, in the labels of the round Play and of Get Notified"

  attr :request, ContentRequest,
    default: nil,
    doc:
      "the Content's Content Request, with its `status`, `download_progress`, `actor_subscriber?` and `requested_by`"

  attr :on_request, :any, default: nil, doc: "the event or JS commands of Request"
  attr :on_get_notified, JS, default: %JS{}, doc: "the JS commands of Get Notified"

  attr :on_episodes, :any,
    default: nil,
    doc:
      "the JS commands opening every TV Show Episode, from a caret joined to Play, or from Episodes when there's nothing to play"

  attr :play_only, :boolean, default: false

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  attr :variant, :string,
    values: ~w(button round),
    default: "button",
    doc: "round: Play with only its icon, as over a poster. Without Media, the usual Request."

  # Only Play, when there's something to play
  def play_or_request_button(%{variant: "round", has_media?: true} = assigns) do
    ~H"""
    <.button
      :if={@play_href}
      id={"#{@id}-play-button"}
      variant="primary"
      size="icon-lg"
      href={@play_href}
      aria-label={dgettext("contents", "%{action} %{title}", action: @play_label, title: @title)}
      title={@play_label}
      class="rounded-full! shadow-overlay"
    >
      <Lucideicons.play />
    </.button>
    """
  end

  def play_or_request_button(%{has_media?: false, play_only: true} = assigns), do: ~H""

  def play_or_request_button(%{has_media?: false, request: nil} = assigns) do
    ~H"""
    <.button
      id={"#{@id}-request-button"}
      size={@size}
      variant="secondary"
      phx-click={@on_request}
      class="w-full"
    >
      <:icon><Lucideicons.download /></:icon>
      {dgettext("contents", "Request")}
    </.button>
    """
  end

  # The status opens My Requests, and fills up while it downloads. A ringing bell shows that the
  # actor will be told when it's ready; until then, a bell joined to it does Get Notified, and
  # then hands the focus to the status, since it goes away.
  def play_or_request_button(%{has_media?: false} = assigns) do
    ~H"""
    <.joined_buttons>
      <.button
        id={"#{@id}-request-status"}
        size={@size}
        variant="secondary"
        navigate={~p"/my-requests"}
        title={status_tooltip(@request)}
        class="relative isolate min-w-0 flex-1 overflow-hidden"
      >
        <:icon :if={@request.actor_subscriber?}><Lucideicons.bell_ring /></:icon>
        <span
          :if={@request.download_progress}
          class="absolute inset-y-0 left-0 -z-10 bg-surface-selected"
          style={"width: #{@request.download_progress}%"}
        ></span>
        {ContentRequestStatus.translated_label(@request.status)}
        <span :if={@request.download_progress} class="sr-only">
          {round(@request.download_progress)}%
        </span>
      </.button>
      <.button
        :if={!@request.actor_subscriber?}
        id={"#{@id}-get-notified-button"}
        size={caret_size(@size)}
        variant="secondary"
        phx-click={JS.focus(@on_get_notified, to: "##{@id}-request-status")}
        aria-label={dgettext("contents", "Get notified when %{title} is ready", title: @title)}
        title={dgettext("contents", "Get notified when it's ready")}
      >
        <Lucideicons.bell />
      </.button>
    </.joined_buttons>
    """
  end

  # Nothing to play yet, such as an episode missing from the Library: every episode instead
  def play_or_request_button(%{play_href: nil, on_episodes: on_episodes} = assigns)
      when on_episodes != nil do
    ~H"""
    <.button
      id={"#{@id}-episodes-button"}
      size={@size}
      variant="primary"
      emphasis
      phx-click={@on_episodes}
      aria-haspopup="dialog"
      class="w-full phx-click-loading:cursor-progress phx-click-loading:opacity-60"
    >
      <:icon><Lucideicons.list_video /></:icon>
      {dgettext("contents", "Episodes")}
    </.button>
    """
  end

  # Play with a caret opening every episode, under one glow so they read as one button
  def play_or_request_button(%{on_episodes: on_episodes} = assigns) when on_episodes != nil do
    ~H"""
    <.joined_buttons class="rounded-control shadow-glow">
      <.button
        id={"#{@id}-play-button"}
        size={@size}
        variant="primary"
        href={@play_href}
        class="min-w-0 flex-1"
      >
        <:icon><Lucideicons.play /></:icon>
        {@play_label}
      </.button>
      <.button
        id={"#{@id}-episodes-button"}
        size={caret_size(@size)}
        variant="primary"
        phx-click={@on_episodes}
        aria-label={dgettext("contents", "All episodes")}
        aria-haspopup="dialog"
        title={dgettext("contents", "All episodes")}
        class="border-l-primary-active! phx-click-loading:cursor-progress phx-click-loading:opacity-60"
      >
        <Lucideicons.chevron_down />
      </.button>
    </.joined_buttons>
    """
  end

  def play_or_request_button(assigns) do
    ~H"""
    <.button
      id={"#{@id}-play-button"}
      size={@size}
      variant="primary"
      emphasis
      href={@play_href}
      disabled={!@play_href}
      class="w-full"
    >
      <:icon><Lucideicons.play /></:icon>
      {@play_label}
    </.button>
    """
  end

  attr :class, :any, default: nil
  slot :inner_block, required: true

  # Buttons joined into one: inner corners squared, one shared border, the focused one on top
  defp joined_buttons(assigns) do
    ~H"""
    <div class={[
      "flex w-full *:focus-visible:z-10 *:not-first:-ml-px *:not-first:rounded-l-none! *:not-last:rounded-r-none!",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # As tall as the button it's joined to
  defp caret_size("sm"), do: "icon-sm"
  defp caret_size("md"), do: "icon"
  defp caret_size("lg"), do: "icon-lg"

  defp status_tooltip(%ContentRequest{actor_subscriber?: true}),
    do: dgettext("contents", "You'll be told when it's ready")

  defp status_tooltip(%ContentRequest{requested_by: nil}),
    do: dgettext("contents", "A deleted user's request")

  defp status_tooltip(%ContentRequest{requested_by: %User{username: username}}),
    do: dgettext("contents", "%{username}'s request", username: username)
end
