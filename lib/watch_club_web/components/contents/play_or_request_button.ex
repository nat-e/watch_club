defmodule WatchClubWeb.Components.Contents.PlayOrRequestButton do
  @moduledoc """
  Play for a Content in the Library, disabled until it's Ready to Play: the User's next TV Show
  Episode has no Media yet. Otherwise Request, or, for one of its Content Request's Request
  Subscribers, how far the request got, in Play's spot.
  `PlayOrRequestButtonLive` loads what it shows and does Request.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Requests.RequestStatus, only: [status_icon: 1, status_words: 3]

  attr :id, :string, required: true
  attr :has_media?, :boolean, required: true

  attr :play_href, :string,
    default: nil,
    doc: "the Player, nil when the User's next TV Show Episode has no Media"

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
      "the JS commands opening every TV Show Episode, from a caret joined to Play while it's enabled"

  attr :size, :string,
    values: ~w(sm md lg),
    default: "md",
    doc: "the button variant's"

  attr :variant, :string,
    values: ~w(button round poster),
    default: "button",
    doc:
      "round: a 40px circle with only an icon, or a ring for the request's status. poster: the same at 48px, with a shadow, over a poster."

  attr :focus_status, :boolean,
    default: false,
    doc: "true moves the focus to the request's status when it shows up, after Request"

  # Only Play. On a solid circle, so a poster doesn't show through it when it's disabled.
  def play_or_request_button(%{variant: variant, has_media?: true} = assigns)
      when variant in ~w(round poster) do
    ~H"""
    <span class={[
      "flex rounded-full has-disabled:bg-canvas",
      @variant == "poster" && "shadow-overlay"
    ]}>
      <.button
        id={"#{@id}-play-button"}
        variant="primary"
        size={if @variant == "poster", do: "icon-lg", else: "icon"}
        href={@play_href}
        disabled={!@play_href}
        aria-label={dgettext("contents", "%{action} %{title}", action: @play_label, title: @title)}
        title={@play_label}
        class="rounded-full!"
      >
        <Lucideicons.play />
      </.button>
    </span>
    """
  end

  def play_or_request_button(
        %{has_media?: false, request: %ContentRequest{actor_subscriber?: true} = request} =
          assigns
      ) do
    assigns
    |> assign(
      percent: download_percent(request),
      words: status_words(request, assigns.release_date, assigns.locale)
    )
    |> request_progress()
  end

  def play_or_request_button(%{variant: variant, has_media?: false} = assigns)
      when variant in ~w(round poster) do
    ~H"""
    <.button
      id={"#{@id}-request-button"}
      variant="primary"
      size={if @variant == "poster", do: "icon-lg", else: "icon"}
      phx-click={@on_request}
      aria-label={
        dgettext("contents", "%{action} %{title}",
          action: dgettext("contents", "Request"),
          title: @title
        )
      }
      title={dgettext("contents", "Request")}
      class={["rounded-full!", @variant == "poster" && "shadow-overlay"]}
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

  # Play with a caret opening every episode, under one glow so they read as one button
  def play_or_request_button(%{play_href: play_href, on_episodes: on_episodes} = assigns)
      when play_href != nil and on_episodes != nil do
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

  # On a solid background, so the Content page's backdrop doesn't show through it when it's
  # disabled
  def play_or_request_button(assigns) do
    ~H"""
    <span class="flex w-full rounded-control has-disabled:bg-canvas">
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
    </span>
    """
  end

  # In Play's spot and shaped like it, but quiet and not clickable: how far it got in words,
  # over a fill from the left, its percentage while it downloads and full when almost ready
  defp request_progress(%{variant: "button"} = assigns) do
    ~H"""
    <.button
      id={"#{@id}-request-status"}
      variant="secondary"
      size={@size}
      aria-disabled="true"
      aria-label={dgettext("contents", "%{title}: %{status}", title: @title, status: @words)}
      phx-mounted={@focus_status && JS.focus()}
      class="relative w-full cursor-not-allowed overflow-hidden border-primary-border! bg-primary-bg! text-text! hover:bg-primary-bg! active:bg-primary-bg!"
    >
      <%!-- The halo token, as the stronger pink no other token offers --%>
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

  # How far it got, in a ring: its percentage while it downloads, full when almost ready, empty
  # while it has none. Stuck, its icon in a grey circle instead. One element for every status,
  # so it keeps the focus when the status changes. Its words are its tooltip and name.
  defp request_progress(assigns) do
    assigns = assign(assigns, :stuck?, assigns.request.status in [:failed, :not_released])

    ~H"""
    <div
      id={"#{@id}-request-status"}
      role={if @stuck?, do: "img", else: "progressbar"}
      aria-label={dgettext("contents", "%{title}: %{status}", title: @title, status: @words)}
      aria-valuenow={!@stuck? && @percent}
      title={@words}
      tabindex="-1"
      phx-mounted={@focus_status && JS.focus()}
      class={[
        "relative flex items-center justify-center rounded-full text-xs font-semibold text-text",
        if(@variant == "poster", do: "size-control-lg shadow-overlay", else: "size-control-md"),
        @stuck? && "bg-surface-raised",
        !@stuck? && @variant == "poster" && "bg-canvas/80"
      ]}
    >
      <.status_icon :if={@stuck?} status={@request.status} class="size-icon" />
      <span :if={@request.status == :downloading} aria-hidden="true">
        {dgettext("contents", "%{percent}%", percent: round(@percent))}
      </span>
      <.status_icon
        :if={!@stuck? and @request.status != :downloading}
        status={@request.status}
        class="size-icon-sm text-text-muted!"
      />
      <svg
        :if={!@stuck?}
        viewBox="0 0 48 48"
        class="absolute inset-0 size-full -rotate-90"
        aria-hidden="true"
      >
        <circle
          cx="24"
          cy="24"
          r="21"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          class="text-border-control"
        />
        <%!-- Left out without a percentage: its round end would show as a dot --%>
        <circle
          :if={@percent && @percent > 0}
          cx="24"
          cy="24"
          r="21"
          fill="none"
          stroke="currentColor"
          stroke-width="3"
          pathLength="100"
          stroke-dasharray={"#{@percent} 100"}
          stroke-linecap="round"
          class="text-primary"
        />
      </svg>
    </div>
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
  defp download_percent(%ContentRequest{status: :downloading, download_progress: percent}),
    do: percent

  defp download_percent(%ContentRequest{status: :importing}), do: 100
  defp download_percent(_request), do: nil

  # As tall as the button it's joined to
  defp caret_size("sm"), do: "icon-sm"
  defp caret_size("md"), do: "icon"
  defp caret_size("lg"), do: "icon-lg"
end
