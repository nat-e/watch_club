defmodule WatchClubWeb.Components.Requests.RequestCard do
  @moduledoc """
  Request card for the My Requests page.

  Takes the `ContentRequest` (with `content`, `status`, `progress` and
  `playable?` loaded) plus the viewer's `locale`, and lays out a flex row of
  two sections:

    - Left (Content): poster with a Play overlay when `playable` (independent of
      status), then the content-type badge, title, year, and an "Add to Library"
      button revealed on card hover (or focus-within).
    - Right (Status): fixed-width tinted panel headed by the status'
      `translated_label`, with a cancel/delete icon, the status body (a progress
      bar for the three in-progress statuses), and "Requested X ago".

  Status is grouped by color: `not_released`/`not_found` gray, the in-flight
  trio (`requested`/`downloading`/`importing`) accent, `failed` danger,
  `completed` success.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeBadge
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Helpers.Time

  alias WatchClub.Contents.ContentView
  alias WatchClub.Requests.ContentRequest
  alias WatchClub.Requests.ContentRequestStatus

  alias WatchClubWeb.Components.Contents.{AddToLibraryButtonLive, PlayOrRequestButtonLive}

  @in_progress_statuses [:requested, :downloading, :importing]

  attr :id, :string
  attr :request, ContentRequest, required: true
  attr :current_user, User, required: true

  def request_card(assigns) do
    ~H"""
    <.card
      as="article"
      data_slot="request-card"
      padding="none"
      id={@id}
      data-status={@request.status}
      class="group/card flex flex-col overflow-hidden @xl:flex-row"
    >
      <.content_section
        id={@request.id}
        content={ContentView.from_content(@request.content, @current_user.settings.locale)}
        current_user={@current_user}
      />

      <.status_section request={@request} current_user={@current_user} />
    </.card>
    """
  end

  # ─── Content section ─────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :content, ContentView, required: true
  attr :current_user, User, required: true

  defp content_section(assigns) do
    ~H"""
    <div class={[
      "relative flex min-w-0 flex-1 items-center gap-group p-group",
      !ContentView.playable?(@content) && "opacity-70"
    ]}>
      <.tmdb_poster
        size="w342"
        path={@content.image_path}
        class="h-36 shrink-0 rounded-control border border-border-subtle shadow-overlay"
      />

      <div class="min-w-0 flex flex-1 flex-col justify-between h-full">
        <div class="flex flex-col gap-tight">
          <.content_type_badge type={@content.type} />
          <.link
            href={WatchClub.Shared.Url.content_details_link(@content.type, @content.external_id)}
            class="truncate text-xl font-heading font-semibold tracking-tight after:absolute after:inset-0 after:content-['']"
          >
            {@content.title}
          </.link>
          <p :if={@content.release_date} class="text-sm text-text-muted">
            {@content.release_date.year}
          </p>
        </div>

        <div class="flex flex-row gap-related">
          <.live_component
            id={"#{@id}-details-play-or-request-button"}
            module={PlayOrRequestButtonLive}
            content={@content}
            current_user={@current_user}
            class="relative z-10 w-auto"
          />
          <.live_component
            id={"#{@id}-details-add-to-library-button"}
            module={AddToLibraryButtonLive}
            content={@content}
            current_user={@current_user}
            on_content_updated={
              fn content_view ->
                send(self(), {:content_libraries_updated, content_view})
              end
            }
            class="relative z-10 w-auto"
          />
        </div>
      </div>
    </div>
    """
  end

  # ─── Status section ──────────────────────────────────────────────────────

  attr :request, ContentRequest, required: true
  attr :current_user, User, required: true

  defp status_section(assigns) do
    assigns = assign(assigns, :style, status_style(assigns.request.status))

    ~H"""
    <div class={[
      "order-first flex w-full shrink-0 flex-col justify-between gap-related border-b p-group @xl:order-0 @xl:w-64 @xl:border-b-0 @xl:border-l",
      @style.bg,
      @style.border
    ]}>
      <div class="flex items-start justify-between gap-tight">
        <p class={["text-xs font-semibold tracking-wider uppercase", @style.text]}>
          {ContentRequestStatus.translated_label(@request.status)}
        </p>
        <.button
          id={"#{@request.id}-cancel"}
          variant="ghost"
          size="icon-sm"
          aria-label={action_label(@request.status)}
          phx-click="cancel-request"
          phx-value-id={@request.id}
        >
          <Lucideicons.x />
        </.button>
      </div>

      <.status_body
        status={@request.status}
        progress={@request.progress}
        content_type={@request.content.type}
      />

      <p class="text-xs text-text-muted">
        Requested {relative_from_now(@request.inserted_at, @current_user.settings.locale)}
      </p>
    </div>
    """
  end

  # ─── Status body (per state) ─────────────────────────────────────────────

  attr :status, :atom, required: true
  attr :progress, :integer, default: nil
  attr :content_type, :atom, required: true

  defp status_body(%{status: status} = assigns) when status in @in_progress_statuses do
    assigns =
      assigns
      |> assign(:pct, in_progress_pct(status, assigns.progress))
      |> assign(:label, in_progress_label(status))

    ~H"""
    <div class="flex flex-col gap-tight">
      <div class="flex items-baseline justify-between">
        <p class="text-sm font-medium text-text">{@label}</p>
        <p class="text-xs tabular-nums text-accent">{@pct}%</p>
      </div>
      <div
        class="h-1.5 w-full overflow-hidden rounded-full bg-surface-inset"
        role="progressbar"
        aria-valuenow={@pct}
        aria-valuemin="0"
        aria-valuemax="100"
        aria-label={@label}
      >
        <div class="h-full bg-accent transition-[width]" style={"width: #{@pct}%"} aria-hidden="true">
        </div>
      </div>
    </div>
    """
  end

  defp status_body(assigns) do
    ~H"""
    <p class={["text-sm", (@status == :completed && "text-text") || "text-text-muted"]}>
      {ContentRequestStatus.status_message(@status, @content_type)}
    </p>
    """
  end

  defp in_progress_label(:requested), do: "Queued"
  defp in_progress_label(:downloading), do: "Downloading"
  defp in_progress_label(:importing), do: "Importing"

  defp in_progress_pct(:requested, _), do: 0
  defp in_progress_pct(:importing, _), do: 100
  defp in_progress_pct(:downloading, nil), do: 0
  defp in_progress_pct(:downloading, n) when is_integer(n), do: max(min(n, 100), 0)

  defp status_style(:completed),
    do: %{bg: "bg-success-bg", border: "border-success-border", text: "text-success"}

  defp status_style(:failed),
    do: %{bg: "bg-danger-bg", border: "border-danger-border", text: "text-danger"}

  defp status_style(status) when status in [:not_released, :not_found],
    do: %{bg: "bg-surface-inset", border: "border-border-subtle", text: "text-text-muted"}

  defp status_style(_status),
    do: %{bg: "bg-accent-bg", border: "border-accent-border", text: "text-accent"}

  defp action_label(:completed), do: "Delete content"
  defp action_label(_), do: "Cancel request"
end
