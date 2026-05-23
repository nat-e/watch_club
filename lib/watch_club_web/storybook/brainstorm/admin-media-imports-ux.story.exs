defmodule WatchClubWeb.Storybook.Brainstorm.AdminMediaImportsUx do
  @moduledoc """
  Temporary brainstorm mockups for the Instance Administrator UX that configures
  and runs Media Imports under `/admin/media/imports`.

  Two screens:

    - `/admin/media/imports` — configurations list, one card per configuration.
    - `/admin/media/imports/:id/history` — run history for a configuration with a
      Run now button.

  Safe to delete after the design decision is accepted or rejected.
  """
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.DropdownMenu
  import WatchClubWeb.Components.UI.Empty
  import WatchClubWeb.Components.UI.Layout
  import WatchClubWeb.Components.UI.LucideIcon
  import WatchClubWeb.Components.UI.Table

  def doc do
    "Temporary brainstorm mockups for the Instance Administrator: a configurations list page and a per-configuration history page."
  end

  def navigation do
    [
      {:list, "List · populated", {:fa, "folder-tree"}},
      {:list_empty, "List · empty", {:fa, "folder-plus"}},
      {:history, "History page", {:fa, "clock-rotate-left"}}
    ]
  end

  # ──────────────────────────────────────────────────────────────────────────
  # List · populated
  # ──────────────────────────────────────────────────────────────────────────

  def render(%{tab: :list} = assigns) do
    assigns = assign(assigns, configurations: configurations())

    ~H"""
    <.admin_frame
      eyebrow="Configurations list"
      title="One card per Media Import Configuration"
    >
      <:description>
        Each card shows the media type icon, label, and filesystem path on one line, with the latest
        run summary (status badge, relative start time, duration) underneath. Run now triggers a new
        Media Import. The card opens the configuration's history page.
      </:description>

      <div class="grid gap-cluster">
        <div class="flex items-center justify-end">
          <.button id="brainstorm-create-configuration" variant="primary">
            <:icon position="start"><.lucide_icon name="plus" /></:icon>
            Configure new import
          </.button>
        </div>

        <ul class="grid list-none gap-related p-0">
          <li :for={configuration <- @configurations}>
            <.configuration_card configuration={configuration} />
          </li>
        </ul>
      </div>
    </.admin_frame>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # List · empty
  # ──────────────────────────────────────────────────────────────────────────

  def render(%{tab: :list_empty} = assigns) do
    ~H"""
    <.admin_frame
      eyebrow="Empty state"
      title="First-time experience for a fresh instance"
    >
      <:description>
        Before the admin has any configurations, the list reads as an empty state. The primary
        action lives inside the empty surface so the admin does not need to find the header button.
      </:description>

      <.empty>
        <:icon><.lucide_icon name="folder_plus" /></:icon>
        <:title>No imports configured yet</:title>
        <:description>
          Configure an import to add medias to your Watch Club instance.
        </:description>
        <.button id="brainstorm-empty-create-configuration" variant="primary">
          <:icon position="start"><.lucide_icon name="plus" /></:icon>
          Configure Import
        </.button>
      </.empty>
    </.admin_frame>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # History page
  # ──────────────────────────────────────────────────────────────────────────

  def render(assigns) do
    assigns =
      assign(assigns,
        configuration: detail_configuration(),
        runs: run_history()
      )

    ~H"""
    <.admin_frame
      eyebrow="History page"
      title="Run history for one configuration"
    >
      <:description>
        Dedicated <code>/admin/media/imports/:id/history</code> page. Header identifies the
        configuration, then the run history table with a Run now button. Editing the filesystem path
        and managing the configuration lives elsewhere (modal from the list card kebab).
      </:description>

      <div class="grid gap-cluster">
        <.history_header configuration={@configuration} />
        <.run_history_table runs={@runs} />
      </div>

      <%!-- Static visual mock of the Run import confirm modal. --%>
      <div class="grid gap-related">
        <p class="text-sm font-semibold tracking-[0.28em] text-accent uppercase">
          Run import modal · visual mock
        </p>
        <.run_import_modal_mock configuration={@configuration} />
      </div>
    </.admin_frame>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Configuration card
  # ──────────────────────────────────────────────────────────────────────────

  attr :configuration, :map, required: true

  defp configuration_card(assigns) do
    ~H"""
    <.card padding="cluster">
      <div class="flex items-start gap-cluster">
        <span class="grid size-control-md shrink-0 place-items-center rounded-control border border-border bg-surface-raised text-text-muted">
          <.lucide_icon name={media_type_icon(@configuration.media_type_label)} class="size-icon" />
        </span>

        <div class="grid min-w-0 flex-1 gap-related">
          <.link navigate="#" class="grid min-w-0 gap-tight text-text outline-none hover:text-text">
            <div class="flex flex-wrap items-baseline gap-related">
              <span class="text-base font-semibold tracking-tight">
                {@configuration.media_type_label}
              </span>
              <span class="min-w-0 truncate font-mono text-sm text-text-muted">
                {@configuration.filesystem_path}
              </span>
              <.badge :if={@configuration.disabled?} variant="muted" size="sm">
                <:icon><.lucide_icon name="pause" /></:icon>
                Disabled
              </.badge>
            </div>
          </.link>

          <.last_run_summary latest_run={@configuration.latest_run} />
        </div>

        <div class="flex shrink-0 items-center gap-tight">
          <.button
            id={"brainstorm-run-now-#{@configuration.id}"}
            variant="primary"
            disabled={@configuration.processing?}
          >
            <:icon position="start">
              <.lucide_icon
                name={(@configuration.processing? && "loader_circle") || "play"}
                class={@configuration.processing? && "animate-spin"}
              />
            </:icon>
            {(@configuration.processing? && "Running…") || "Run now"}
          </.button>

          <.dropdown_menu id={"brainstorm-actions-#{@configuration.id}"}>
            <:trigger>
              <.button
                id={"brainstorm-actions-trigger-#{@configuration.id}"}
                variant="secondary"
                size="icon"
                aria-label={"Actions for #{@configuration.media_type_label}"}
              >
                <.lucide_icon name="ellipsis_vertical" />
              </.button>
            </:trigger>

            <.dropdown_menu_item id={"brainstorm-history-#{@configuration.id}"}>
              <.lucide_icon name="clock" /> View history
            </.dropdown_menu_item>
            <.dropdown_menu_item id={"brainstorm-edit-#{@configuration.id}"}>
              <.lucide_icon name="pencil" /> Edit path…
            </.dropdown_menu_item>
            <.dropdown_menu_item id={"brainstorm-toggle-#{@configuration.id}"}>
              <.lucide_icon name={(@configuration.disabled? && "play") || "pause"} />
              {(@configuration.disabled? && "Enable") || "Disable"}
            </.dropdown_menu_item>
            <.dropdown_menu_separator />
            <.dropdown_menu_item id={"brainstorm-delete-#{@configuration.id}"} variant="destructive">
              <.lucide_icon name="trash" /> Delete…
            </.dropdown_menu_item>
          </.dropdown_menu>
        </div>
      </div>
    </.card>
    """
  end

  attr :latest_run, :map, required: true

  defp last_run_summary(%{latest_run: %{status: :never_run}} = assigns) do
    ~H"""
    <div class="flex items-center gap-related text-xs text-text-muted">
      <.run_status_badge status={:never_run} />
    </div>
    """
  end

  defp last_run_summary(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-related text-xs text-text-muted">
      <.run_status_badge status={@latest_run.status} />
      <span>{@latest_run.started_relative}</span>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # History page partials
  # ──────────────────────────────────────────────────────────────────────────

  attr :configuration, :map, required: true

  defp history_header(assigns) do
    ~H"""
    <div class="grid gap-cluster">
      <.link
        navigate="#"
        class="inline-flex items-center gap-tight self-start text-sm font-medium text-text-muted outline-none hover:text-text"
      >
        <.lucide_icon name="arrow_left" class="size-icon-sm" /> Back to imports
      </.link>

      <div class="flex flex-col gap-cluster sm:flex-row sm:items-start sm:justify-between">
        <div class="flex min-w-0 items-center gap-cluster">
          <span class="grid size-control-lg shrink-0 place-items-center rounded-control border border-border bg-surface-raised text-text-muted">
            <.lucide_icon
              name={media_type_icon(@configuration.media_type_label)}
              class="size-icon-lg"
            />
          </span>
          <div class="grid min-w-0 gap-tight">
            <h1 class="text-2xl font-heading font-semibold tracking-tight">
              {@configuration.media_type_label}
            </h1>
            <p class="truncate font-mono text-sm text-text-muted">
              {@configuration.filesystem_path}
            </p>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-cluster sm:shrink-0">
          <.button
            id="brainstorm-history-run-import"
            variant="primary"
            disabled={@configuration.processing?}
          >
            <:icon position="start">
              <.lucide_icon
                name={(@configuration.processing? && "loader_circle") || "play"}
                class={@configuration.processing? && "animate-spin"}
              />
            </:icon>
            {(@configuration.processing? && "Running…") || "Run import"}
          </.button>
        </div>
      </div>
    </div>
    """
  end

  attr :runs, :list, required: true

  defp run_history_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head class="text-left">Status</.table_head>
          <.table_head class="text-left">Started</.table_head>
          <.table_head class="text-left">Duration</.table_head>
          <.table_head class="text-left">Trigger</.table_head>
          <.table_head class="text-left">Refresh metadata</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row :for={run <- @runs}>
          <.table_cell class="text-left">
            <.run_status_badge status={run.status} />
          </.table_cell>
          <.table_cell class="text-left text-text-muted">{run.started_at}</.table_cell>
          <.table_cell class="text-left text-text-muted">
            <span :if={run.status != :processing}>{run.duration}</span>
            <span :if={run.status == :processing} aria-hidden="true" class="text-text-subtle">—</span>
          </.table_cell>
          <.table_cell class="text-left">
            <.badge variant="muted" size="sm">
              <:icon>
                <.lucide_icon name={(run.trigger == "Manual" && "hand") || "calendar"} />
              </:icon>
              {run.trigger}
            </.badge>
          </.table_cell>
          <.table_cell class="text-left">
            <.refresh_metadata_badge value={run.refresh_metadata} />
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  attr :value, :string, required: true

  defp refresh_metadata_badge(%{value: "On"} = assigns) do
    ~H"""
    <.badge variant="accent" size="sm">
      <:icon><.lucide_icon name="refresh_cw" /></:icon>
      On
    </.badge>
    """
  end

  defp refresh_metadata_badge(assigns) do
    ~H"""
    <.badge variant="muted" size="sm">Off</.badge>
    """
  end

  attr :configuration, :map, required: true

  defp run_import_modal_mock(assigns) do
    ~H"""
    <div class="relative isolate rounded-card border border-border-subtle bg-surface-inset p-cluster">
      <div class="absolute inset-0 rounded-card bg-scrim/40 backdrop-blur-sm" aria-hidden="true" />
      <div class="relative mx-auto grid w-full max-w-lg gap-cluster rounded-card border border-border bg-surface-overlay p-cluster shadow-overlay">
        <header class="grid gap-tight pr-10">
          <h3 class="text-lg font-semibold leading-none">Run media import</h3>
          <p class="text-sm text-text-muted">
            Start a new Media Import for {@configuration.media_type_label} ·
            <span class="font-mono">{@configuration.filesystem_path}</span>.
          </p>
        </header>

        <label
          for="brainstorm-modal-refresh-metadata"
          class="flex cursor-pointer items-start gap-related rounded-control border border-border bg-surface p-group"
        >
          <input
            id="brainstorm-modal-refresh-metadata"
            type="checkbox"
            class="mt-1 size-4 rounded-control border-border accent-accent"
          />
          <span class="grid gap-tight">
            <span class="text-sm font-medium text-text">Refresh metadata</span>
            <span class="text-xs text-text-muted">
              When enabled, the media will be re-computed and potentially re-matched to another content.
            </span>
          </span>
        </label>

        <footer class="flex flex-col-reverse gap-related sm:flex-row sm:justify-end">
          <.button id="brainstorm-modal-cancel" variant="secondary">Cancel</.button>
          <.button id="brainstorm-modal-confirm" variant="primary">
            <:icon position="start"><.lucide_icon name="play" /></:icon>
            Run import
          </.button>
        </footer>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Status badge
  # ──────────────────────────────────────────────────────────────────────────

  attr :status, :atom, required: true

  defp run_status_badge(%{status: :completed} = assigns) do
    ~H"""
    <.badge variant="success" size="sm">
      <:icon><.lucide_icon name="check_circle" /></:icon>
      Completed
    </.badge>
    """
  end

  defp run_status_badge(%{status: :failed} = assigns) do
    ~H"""
    <.badge variant="danger" size="sm">
      <:icon><.lucide_icon name="circle_alert" /></:icon>
      Failed
    </.badge>
    """
  end

  defp run_status_badge(%{status: :processing} = assigns) do
    ~H"""
    <.badge variant="accent" size="sm">
      <:icon><.lucide_icon name="loader_circle" class="animate-spin" /></:icon>
      Processing
    </.badge>
    """
  end

  defp run_status_badge(%{status: :pending} = assigns) do
    ~H"""
    <.badge variant="muted" size="sm">
      <:icon><.lucide_icon name="clock" /></:icon>
      Pending
    </.badge>
    """
  end

  defp run_status_badge(%{status: :never_run} = assigns) do
    ~H"""
    <.badge variant="muted" size="sm">
      <:icon><.lucide_icon name="circle_dashed" /></:icon>
      Never imported
    </.badge>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Frame + helpers
  # ──────────────────────────────────────────────────────────────────────────

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  slot :description, required: true
  slot :inner_block, required: true

  defp admin_frame(assigns) do
    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen bg-canvas p-page py-page-y text-text">
      <div class="mx-auto grid max-w-[80rem] gap-section">
        <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
          <div class="grid gap-related">
            <div class="flex flex-wrap items-center gap-related">
              <.badge variant="accent" size="sm">Brainstorm · temporary</.badge>
              <span class="text-sm font-medium text-text-subtle">/admin/media/imports</span>
            </div>
            <p class="text-sm font-semibold tracking-[0.28em] text-accent uppercase">{@eyebrow}</p>
            <h1 class="max-w-4xl text-3xl leading-tight font-semibold tracking-tight text-text">
              {@title}
            </h1>
            <p class="max-w-readable text-sm leading-6 text-text-muted">{render_slot(@description)}</p>
          </div>
        </section>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp media_type_icon("Movies"), do: "clapperboard"
  defp media_type_icon("TV Show Episodes"), do: "tv"
  defp media_type_icon("Audiobooks"), do: "headphones"
  defp media_type_icon("Ebooks"), do: "book_open"
  defp media_type_icon(_), do: "folder"

  # ──────────────────────────────────────────────────────────────────────────
  # Mock data
  # ──────────────────────────────────────────────────────────────────────────

  defp configurations do
    [
      %{
        id: "01HZX-movies",
        media_type_label: "Movies",
        filesystem_path: "/media/movies",
        disabled?: false,
        processing?: false,
        latest_run: %{
          status: :completed,
          started_relative: "12 minutes ago",
          duration: "18m 04s"
        }
      },
      %{
        id: "01HZX-shows",
        media_type_label: "TV Show Episodes",
        filesystem_path: "/media/shows",
        disabled?: false,
        processing?: true,
        latest_run: %{
          status: :processing,
          started_relative: "2 minutes ago",
          duration: "2m 12s · running"
        }
      },
      %{
        id: "01HZX-audiobooks",
        media_type_label: "Audiobooks",
        filesystem_path: "/media/audiobooks",
        disabled?: true,
        processing?: false,
        latest_run: %{
          status: :failed,
          started_relative: "yesterday",
          duration: "0s"
        }
      },
      %{
        id: "01HZX-ebooks-new",
        media_type_label: "Ebooks",
        filesystem_path: "/import/staging/ebooks",
        disabled?: false,
        processing?: false,
        latest_run: %{status: :never_run}
      }
    ]
  end

  defp detail_configuration do
    %{
      id: "01HZX-shows",
      media_type_label: "TV Show Episodes",
      filesystem_path: "/media/shows",
      disabled?: false,
      processing?: true
    }
  end

  defp run_history do
    [
      %{
        id: "run-1",
        status: :processing,
        started_at: "May 23, 14:02",
        duration: "2m 12s · running",
        trigger: "Manual",
        refresh_metadata: "Off"
      },
      %{
        id: "run-2",
        status: :completed,
        started_at: "May 22, 03:00",
        duration: "18m 11s",
        trigger: "Scheduled",
        refresh_metadata: "Off"
      },
      %{
        id: "run-3",
        status: :failed,
        started_at: "May 21, 03:00",
        duration: "0s",
        trigger: "Scheduled",
        refresh_metadata: "Off"
      },
      %{
        id: "run-4",
        status: :completed,
        started_at: "May 20, 21:43",
        duration: "28m 22s",
        trigger: "Manual",
        refresh_metadata: "On"
      },
      %{
        id: "run-5",
        status: :completed,
        started_at: "May 12, 03:00",
        duration: "24m 17s",
        trigger: "Scheduled",
        refresh_metadata: "Off"
      }
    ]
  end
end
