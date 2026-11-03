defmodule WatchClubWeb.Admin.MediaSources.HistoryHeader do
  @moduledoc """
  Header for the per-`Media Source` history page, under the app bar that shows
  its name and its back button.

  Includes the media-type icon + label + path, and the "Run import" primary
  CTA. The button is disabled while a `Media Import` is processing for this
  `Media Source`.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.{MediaTypeBadge, SourceIdentifier, SourceTypeIcon}

  attr :media_source, Source, required: true

  def history_header(assigns) do
    assigns =
      assign(
        assigns,
        :processing?,
        match?(%Import{status: :processing}, List.first(assigns.media_source.imports))
      )

    ~H"""
    <div class="flex flex-col gap-cluster sm:flex-row sm:items-center sm:justify-between">
      <.inline space="cluster" class="min-w-0">
        <.source_type_icon type={@media_source.source_type} size="header" />
        <.cluster space="related" class="min-w-0">
          <.media_type_badge media_type={@media_source.media_type} />
          <.source_identifier media_source={@media_source} />
        </.cluster>
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
    """
  end

  defp run_import_label(true), do: dgettext("admin_media_imports", "Running…")
  defp run_import_label(false), do: dgettext("admin_media_imports", "Run import")
end
