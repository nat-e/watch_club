defmodule WatchClubWeb.Admin.MediaImports.HistoryHeader do
  @moduledoc """
  Header for the per-configuration history page.

  Includes a back link to the imports list, the media-type icon + label + path,
  and the "Run import" primary CTA. The button is disabled while a `Media
  Import` is processing for this configuration.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.{FilesystemPath, MediaTypeIcon}

  alias WatchClub.Media.{ImportConfiguration, ImportRun, MediaType}

  attr :configuration, ImportConfiguration, required: true

  def history_header(assigns) do
    assigns = assign(assigns, :processing?, processing?(List.first(assigns.configuration.imports)))

    ~H"""
    <.stack space="cluster">
      <.link
        navigate={~p"/admin/media/imports"}
        class="inline-flex items-center gap-tight self-start text-sm font-medium text-text-muted outline-none hover:text-text"
      >
        <Lucideicons.arrow_left class="size-icon-sm" />
        {dgettext("admin_media_imports", "Back to imports")}
      </.link>

      <div class="flex flex-col gap-cluster sm:flex-row sm:items-start sm:justify-between">
        <.inline space="cluster" class="min-w-0">
          <span class="grid size-control-lg shrink-0 place-items-center rounded-control border border-border bg-surface-raised text-text-muted">
            <.media_type_icon media_type={@configuration.media_type} class="size-icon-lg" />
          </span>
          <.stack space="tight" class="min-w-0">
            <h1 class="text-2xl font-heading font-semibold tracking-tight">
              {MediaType.translated_plural_label(@configuration.media_type)}
            </h1>
            <.filesystem_path path={@configuration.filesystem_path} class="self-start" />
          </.stack>
        </.inline>

        <.button
          id="history-run-import-button"
          variant="primary"
          disabled={@processing?}
          phx-click="open_run_import_modal"
          phx-value-id={@configuration.id}
        >
          <:icon position="start">
            <Lucideicons.loader_circle :if={@processing?} class="animate-spin" />
            <Lucideicons.play :if={!@processing?} />
          </:icon>
          {run_import_label(@processing?)}
        </.button>
      </div>
    </.stack>
    """
  end

  defp processing?(%ImportRun{status: :processing}), do: true
  defp processing?(_), do: false

  defp run_import_label(true), do: dgettext("admin_media_imports", "Running…")
  defp run_import_label(false), do: dgettext("admin_media_imports", "Run import")
end
