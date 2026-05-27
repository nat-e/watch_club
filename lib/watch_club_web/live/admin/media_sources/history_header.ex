defmodule WatchClubWeb.Admin.MediaSources.HistoryHeader do
  @moduledoc """
  Header for the per-`Media Source` history page.

  Includes a back link to the Media Sources list, the media-type icon + label
  + path, and the "Run import" primary CTA. The button is disabled while a
  `Media Import` is processing for this `Media Source`.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.{FilesystemPath, MediaTypeIcon}

  alias WatchClub.Media.{MediaImport, MediaSource, MediaType}

  attr :media_source, MediaSource, required: true

  def history_header(assigns) do
    assigns =
      assign(assigns, :processing?, processing?(List.first(assigns.media_source.imports)))

    ~H"""
    <.stack space="cluster">
      <.link
        navigate={~p"/admin/media/sources"}
        class="inline-flex items-center gap-tight self-start text-sm font-medium text-text-muted outline-none hover:text-text"
      >
        <Lucideicons.arrow_left class="size-icon-sm" />
        {dgettext("admin_media_imports", "Back to Media Sources")}
      </.link>

      <div class="flex flex-col gap-cluster sm:flex-row sm:items-start sm:justify-between">
        <.inline space="cluster" class="min-w-0">
          <span class="grid size-control-lg shrink-0 place-items-center rounded-control border border-border bg-surface-raised text-text-muted">
            <.media_type_icon media_type={@media_source.media_type} class="size-icon-lg" />
          </span>
          <.stack space="tight" class="min-w-0">
            <h1 class="text-2xl font-heading font-semibold tracking-tight">
              {MediaType.translated_plural_label(@media_source.media_type)}
            </h1>
            <.filesystem_path path={@media_source.filesystem_path} class="self-start" />
          </.stack>
        </.inline>

        <.button
          id="history-run-import-button"
          variant="primary"
          disabled={@processing?}
          phx-click="open_run_import_modal"
          phx-value-id={@media_source.id}
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

  defp processing?(%MediaImport{status: :processing}), do: true
  defp processing?(_), do: false

  defp run_import_label(true), do: dgettext("admin_media_imports", "Running…")
  defp run_import_label(false), do: dgettext("admin_media_imports", "Run import")
end
