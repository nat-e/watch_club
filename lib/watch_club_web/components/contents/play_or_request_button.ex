defmodule WatchClubWeb.Components.Contents.PlayOrRequestButton do
  @moduledoc """
  Play for a Content with Media. Otherwise Request, or, for one of its Content Request's Request
  Subscribers, how far the request got, in Play's spot.
  `PlayOrRequestButtonLive` loads what it shows and does Request.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Requests.RequestStatus, only: [status_icon: 1, status_words: 3]

  attr :id, :string, required: true
  attr :has_media?, :boolean, required: true
  attr :play_href, :string, default: nil, doc: "the Player, nil when there's nothing to play"
  attr :play_label, :string, required: true, doc: "such as Play, or Resume S01E03"

  attr :title, :string,
    default: nil,
    doc: "the Content's name, in the labels of the round button and of the request's status"

  attr :request, ContentRequest,
    default: nil,
    doc:
      "the Content's Content Request, with its `status`, `download_progress` and `actor_subscriber?`"

  attr :release_date, Date, default: nil, doc: "the Content's, for its Content Request's status"
  attr :locale, :atom, default: nil, doc: "a `UserLocale`, for the Content Request's status"

  attr :on_request, :any, default: nil, doc: "the event or JS commands of Request"

  attr :on_episodes, :any,
    default: nil,
    doc:
      "the JS commands opening every TV Show Episode, from a caret joined to Play, or from Episodes when there's nothing to play"

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md"

  attr :variant, :string,
    values: ~w(button round),
    default: "button",
    doc:
      "round: a circle with only an icon, or a ring for the request's status. The lg one sits over posters, with a shadow."

  # Only Play, when there's something to play
  def play_or_request_button(%{variant: "round", has_media?: true} = assigns) do
    ~H"""
    <.button
      :if={@play_href}
      id={"#{@id}-play-button"}
      variant="primary"
      size={icon_size(@size)}
      href={@play_href}
      aria-label={dgettext("contents", "%{action} %{title}", action: @play_label, title: @title)}
      title={@play_label}
      class={["rounded-full!", @size == "lg" && "shadow-overlay"]}
    >
      <Lucideicons.play />
    </.button>
    """
  end

  # How far it got, in a ring: its percentage while it downloads, full when almost ready, empty
  # while it has none. Stuck, its icon in a grey circle instead. Its words are its tooltip.
  def play_or_request_button(
        %{variant: "round", has_media?: false, request: %ContentRequest{actor_subscriber?: true}} =
          assigns
      ) do
    assigns =
      assign(assigns,
        percent: progress_percent(assigns.request),
        words: status_words(assigns.request, assigns.release_date, assigns.locale)
      )

    ~H"""
    <span
      :if={@request.status in [:failed, :not_released]}
      id={"#{@id}-request-status"}
      role="img"
      aria-label={dgettext("contents", "%{title}: %{status}", title: @title, status: @words)}
      title={@words}
      class={[
        "flex items-center justify-center rounded-full bg-surface-raised",
        control_size(@size),
        @size == "lg" && "shadow-overlay"
      ]}
    >
      <.status_icon status={@request.status} class="size-icon" />
    </span>
    <div
      :if={@request.status not in [:failed, :not_released]}
      id={"#{@id}-request-status"}
      role="progressbar"
      aria-label={dgettext("contents", "Request progress for %{title}", title: @title)}
      aria-valuemin="0"
      aria-valuemax="100"
      aria-valuenow={@percent}
      aria-valuetext={@words}
      title={@words}
      class={[
        "relative flex items-center justify-center rounded-full text-xs font-semibold text-text",
        control_size(@size),
        @size == "lg" && "bg-canvas/80 shadow-overlay"
      ]}
    >
      <span :if={@percent} aria-hidden="true">{round(@percent)}%</span>
      <Lucideicons.download
        :if={!@percent}
        class="size-icon-sm text-text-muted"
        aria-hidden="true"
      />
      <svg viewBox="0 0 48 48" class="absolute inset-0 size-full -rotate-90" aria-hidden="true">
        <circle
          cx="24"
          cy="24"
          r="21"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          class="text-border-control"
        />
        <circle
          cx="24"
          cy="24"
          r="21"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          pathLength="100"
          stroke-dasharray={"#{@percent || 0} 100"}
          stroke-linecap="round"
          class="text-primary"
        />
      </svg>
    </div>
    """
  end

  # In Play's spot and shaped like it, but quiet and not clickable: how far it got in words,
  # over a fill from the left, its percentage while it downloads and full when almost ready
  def play_or_request_button(
        %{has_media?: false, request: %ContentRequest{actor_subscriber?: true}} = assigns
      ) do
    assigns =
      assign(assigns,
        percent: progress_percent(assigns.request),
        words: status_words(assigns.request, assigns.release_date, assigns.locale)
      )

    ~H"""
    <.button
      id={"#{@id}-request-status"}
      variant="secondary"
      size={@size}
      aria-disabled="true"
      aria-label={
        dgettext("contents", "%{action} %{title}: %{status}",
          action: @play_label,
          title: @title,
          status: @words
        )
      }
      class="relative w-full cursor-not-allowed overflow-hidden border-primary-border! bg-primary-bg! font-medium text-text! hover:bg-primary-bg! active:bg-primary-bg!"
    >
      <span
        :if={@percent}
        aria-hidden="true"
        class="absolute inset-y-0 left-0 bg-primary-ring"
        style={"width: #{@percent}%"}
      ></span>
      <span class="relative flex min-w-0 items-center gap-related">
        <.status_icon
          status={@request.status}
          class={["size-icon", @request.status != :failed && "text-text!"]}
        />
        <span class="truncate">{@words}</span>
      </span>
    </.button>
    """
  end

  def play_or_request_button(%{variant: "round", has_media?: false} = assigns) do
    ~H"""
    <.button
      id={"#{@id}-request-button"}
      variant="primary"
      size={icon_size(@size)}
      phx-click={@on_request}
      aria-label={
        dgettext("contents", "%{action} %{title}",
          action: dgettext("contents", "Request"),
          title: @title
        )
      }
      title={dgettext("contents", "Request")}
      class={["rounded-full!", @size == "lg" && "shadow-overlay"]}
    >
      <Lucideicons.download />
    </.button>
    """
  end

  def play_or_request_button(%{has_media?: false} = assigns) do
    ~H"""
    <.button
      id={"#{@id}-request-button"}
      size={@size}
      variant="primary"
      phx-click={@on_request}
      class="w-full"
    >
      <:icon><Lucideicons.download /></:icon>
      {dgettext("contents", "Request")}
    </.button>
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
        size={icon_size(@size)}
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

  # How far a Content Request got, in %: nil while it has no percentage
  defp progress_percent(%ContentRequest{status: :downloading, download_progress: percent}),
    do: percent

  defp progress_percent(%ContentRequest{status: :importing}), do: 100
  defp progress_percent(_request), do: nil

  # A square button as tall as a button of this size
  defp icon_size("sm"), do: "icon-sm"
  defp icon_size("md"), do: "icon"
  defp icon_size("lg"), do: "icon-lg"

  defp control_size("sm"), do: "size-control-sm"
  defp control_size("md"), do: "size-control-md"
  defp control_size("lg"), do: "size-control-lg"
end
