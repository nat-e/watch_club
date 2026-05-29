defmodule WatchClubWeb.Components.Requests.RequestCard do
  @moduledoc """
  Request card for the My Requests page.

  Layout:

    - Left (What): poster with a Play overlay when available, then a stack
      of content-type badge + title + metadata + Add to Library button.
      The Add button is revealed on card hover (or focus-within).
    - Right (Status): tinted panel with a state header + cancel/delete icon
      at the top, state body in the middle (always a progress bar for the
      three in-progress states), and "Requested X ago" at the bottom.

  Seven status values, grouped by color:
    * `not_released` / `not_found` — gray, can't be downloaded
    * `requested` / `downloading` / `processing` — accent (purple), in flight
    * `failed` — danger (red)
    * `available` — success (green)

  The status-section action is always an `×` icon button. Aria-label is
  "Delete content" for `available` (the file exists on the server) and
  "Cancel request" for every other status (no file yet).
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeBadge

  @valid_statuses ~w(not_released not_found requested downloading processing available failed)

  attr :id, :string, required: true

  attr :title, :string, required: true
  attr :year, :integer, default: nil
  attr :runtime, :string, default: nil
  attr :country_flag, :string, default: nil
  attr :language_label, :string, default: nil
  attr :poster_url, :string, default: nil
  attr :content_type, :atom, values: [:movie, :tv_show, :book], default: :movie

  attr :status, :string, values: @valid_statuses, required: true

  attr :progress, :integer, default: nil
  attr :requested_at_label, :string, default: nil

  def request_card(assigns) do
    ~H"""
    <article
      id={@id}
      data-slot="request-card"
      data-status={@status}
      class="group/card relative grid grid-cols-[minmax(0,1fr)_16rem] overflow-hidden rounded-card border border-border-subtle bg-surface shadow-card"
    >
      <.what_section
        id={@id}
        title={@title}
        year={@year}
        runtime={@runtime}
        country_flag={@country_flag}
        language_label={@language_label}
        poster_url={@poster_url}
        content_type={@content_type}
        status={@status}
      />

      <.status_section
        id={@id}
        status={@status}
        progress={@progress}
        content_type={@content_type}
        requested_at_label={@requested_at_label}
      />
    </article>
    """
  end

  # ─── What section ────────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :year, :integer, default: nil
  attr :runtime, :string, default: nil
  attr :country_flag, :string, default: nil
  attr :language_label, :string, default: nil
  attr :poster_url, :string, default: nil
  attr :content_type, :atom, required: true
  attr :status, :string, required: true

  defp what_section(assigns) do
    ~H"""
    <div class={["flex items-center gap-group p-group", @status != "available" && "opacity-70"]}>
      <div class="relative aspect-2/3 h-36 shrink-0 overflow-hidden rounded-control border border-border-subtle bg-surface-inset shadow-overlay">
        <img
          :if={@poster_url}
          src={@poster_url}
          alt=""
          class={[
            "absolute inset-0 h-full w-full object-cover",
            @status != "available" && "opacity-70"
          ]}
        />
        <div
          :if={!@poster_url}
          class="absolute inset-0 flex items-center justify-center text-text-muted"
        >
          <Lucideicons.image />
        </div>

        <button
          :if={@status == "available"}
          id={"#{@id}-play"}
          type="button"
          aria-label="Play"
          class="group/play absolute inset-0 flex items-center justify-center transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus-ring"
        >
          <span class="flex size-12 items-center justify-center rounded-full bg-white text-on-primary shadow-overlay transition-transform group-hover/play:scale-105 group-active/play:scale-100">
            <Lucideicons.play class="size-icon" />
          </span>
        </button>
      </div>

      <div class="min-w-0 flex-1">
        <.stack space="tight">
          <.content_type_badge type={@content_type} />

          <h3 class="truncate text-xl font-heading font-semibold tracking-tight text-text">
            {@title}
          </h3>

          <p class="truncate text-sm text-text-muted">
            <span :if={@year}>{@year}</span>
            <span :if={@year && @runtime} aria-hidden="true"> · </span>
            <span :if={@runtime}>{@runtime}</span>
            <span :if={(@year || @runtime) && (@country_flag || @language_label)} aria-hidden="true">
              ·
            </span>
            <span :if={@country_flag} aria-hidden="true">{@country_flag}</span>
            <span :if={@language_label}>{@language_label}</span>
          </p>
        </.stack>

        <.button
          id={"#{@id}-add-to-library"}
          variant="accent"
          size="sm"
          class="mt-cluster opacity-0 transition-opacity group-hover/card:opacity-100 group-focus-within/card:opacity-100"
        >
          <:icon><Lucideicons.plus /></:icon>
          Add to Library
        </.button>
      </div>
    </div>
    """
  end

  # ─── Status section ──────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :status, :string, required: true
  attr :progress, :integer, default: nil
  attr :content_type, :atom, required: true
  attr :requested_at_label, :string, default: nil

  defp status_section(assigns) do
    ~H"""
    <div class={[
      "flex flex-col justify-between gap-related border-l p-group",
      panel_bg_class(@status),
      panel_border_class(@status)
    ]}>
      <div class="flex items-start justify-between gap-tight">
        <p class={[
          "text-xs font-semibold tracking-wider uppercase",
          status_text_class(@status)
        ]}>
          {state_header(@status)}
        </p>
        <.button
          id={"#{@id}-cancel"}
          variant="ghost"
          size="icon-sm"
          aria-label={action_label(@status)}
        >
          <Lucideicons.x />
        </.button>
      </div>

      <.status_body status={@status} progress={@progress} content_type={@content_type} />

      <p :if={@requested_at_label} class="text-xs text-text-muted">
        Requested {@requested_at_label}
      </p>
    </div>
    """
  end

  # ─── Status body (per state) ─────────────────────────────────────────────

  attr :status, :string, required: true
  attr :progress, :integer, default: nil
  attr :content_type, :atom, required: true

  defp status_body(%{status: "available"} = assigns) do
    ~H"""
    <p class="text-sm text-text">
      Ready when you are.
    </p>
    """
  end

  defp status_body(%{status: status} = assigns)
       when status in ["requested", "downloading", "processing"] do
    pct = in_progress_pct(assigns.status, assigns.progress)
    assigns = assigns |> assign(:pct, pct) |> assign(:label, in_progress_label(status))

    ~H"""
    <div>
      <div class="flex items-baseline justify-between">
        <p class="text-sm font-medium text-text">{@label}</p>
        <p class="text-xs tabular-nums text-accent">{@pct}%</p>
      </div>
      <div class="mt-tight h-1.5 w-full overflow-hidden rounded-full bg-surface-inset">
        <div
          class="h-full bg-accent transition-[width]"
          style={"width: #{@pct}%"}
          aria-hidden="true"
        >
        </div>
      </div>
    </div>
    """
  end

  defp status_body(%{status: "failed"} = assigns) do
    ~H"""
    <p class="text-sm text-text-muted">
      There was an error downloading the {content_type_noun(@content_type)}.
    </p>
    """
  end

  defp status_body(%{status: "not_released"} = assigns) do
    ~H"""
    <p class="text-sm text-text-muted">
      This {content_type_noun(@content_type)} hasn't been released yet.
    </p>
    """
  end

  defp status_body(%{status: "not_found"} = assigns) do
    ~H"""
    <p class="text-sm text-text-muted">
      We couldn't find this {content_type_noun(@content_type)}.
    </p>
    """
  end

  # ─── State helpers ───────────────────────────────────────────────────────

  defp state_header("available"), do: "Ready to play"
  defp state_header("failed"), do: "Failed"
  defp state_header("not_released"), do: "Not released"
  defp state_header("not_found"), do: "Not found"
  defp state_header(_), do: "In progress"

  defp in_progress_label("requested"), do: "Queued"
  defp in_progress_label("downloading"), do: "Downloading"
  defp in_progress_label("processing"), do: "Processing"

  defp in_progress_pct("requested", _), do: 0
  defp in_progress_pct("processing", _), do: 100
  defp in_progress_pct("downloading", nil), do: 0
  defp in_progress_pct("downloading", n) when is_integer(n), do: max(min(n, 100), 0)

  defp panel_bg_class("available"), do: "bg-success-bg"
  defp panel_bg_class("failed"), do: "bg-danger-bg"
  defp panel_bg_class(status) when status in ["not_released", "not_found"], do: "bg-surface-inset"
  defp panel_bg_class(_), do: "bg-accent-bg"

  defp panel_border_class("available"), do: "border-success-border"
  defp panel_border_class("failed"), do: "border-danger-border"

  defp panel_border_class(status) when status in ["not_released", "not_found"],
    do: "border-border-subtle"

  defp panel_border_class(_), do: "border-accent-border"

  defp status_text_class("available"), do: "text-success"
  defp status_text_class("failed"), do: "text-danger"

  defp status_text_class(status) when status in ["not_released", "not_found"],
    do: "text-text-muted"

  defp status_text_class(_), do: "text-accent"

  defp action_label("available"), do: "Delete content"
  defp action_label(_), do: "Cancel request"

  defp content_type_noun(:movie), do: "movie"
  defp content_type_noun(:tv_show), do: "TV show"
  defp content_type_noun(:book), do: "book"
end
