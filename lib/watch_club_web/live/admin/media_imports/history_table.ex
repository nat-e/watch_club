defmodule WatchClubWeb.Admin.MediaImports.HistoryTable do
  @moduledoc """
  Run history table for one `Media Import Configuration`.

  Columns: Status, Started, Duration, Trigger, Refresh metadata.
  Duration is rendered as `—` for in-progress runs because there is no finished
  timestamp yet.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaImports.RefreshMetadataBadge
  import WatchClubWeb.Admin.MediaImports.RunStatusBadge

  alias WatchClub.Media.ImportRun
  alias WatchClubWeb.Helpers.Time

  attr :runs, :list, required: true
  attr :locale, :atom, required: true

  def history_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head class="text-left">{dgettext("admin_media_imports", "Status")}</.table_head>
          <.table_head class="text-left">{dgettext("admin_media_imports", "Started")}</.table_head>
          <.table_head class="text-left">{dgettext("admin_media_imports", "Duration")}</.table_head>
          <.table_head class="text-left">{dgettext("admin_media_imports", "Trigger")}</.table_head>
          <.table_head class="text-left">
            {dgettext("admin_media_imports", "Refresh metadata")}
          </.table_head>
          <.table_head class="w-0">
            <span class="sr-only">{dgettext("admin_media_imports", "Actions")}</span>
          </.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row :for={run <- @runs}>
          <.table_cell class="text-left">
            <.run_status_badge status={run.status} />
          </.table_cell>
          <.table_cell class="text-left text-text-muted">
            {Time.relative_from_now(run.inserted_at, @locale)}
          </.table_cell>
          <.table_cell class="text-left text-text-muted">
            {duration(run)}
          </.table_cell>
          <.table_cell class="text-left">
            <.trigger_badge triggered_manually?={run.triggered_manually?} />
          </.table_cell>
          <.table_cell class="text-left">
            <.refresh_metadata_badge value={run.refresh_metadata?} />
          </.table_cell>
          <.table_cell class="text-right">
            <.button
              :if={run.status == :processing}
              id={"cancel-run-#{run.id}"}
              variant="secondary"
              class="text-text-muted hover:text-text"
              phx-click="cancel_run"
              phx-value-id={run.id}
              aria-label={dgettext("admin_media_imports", "Cancel")}
            >
              <Lucideicons.x />
              {dgettext("admin_media_imports", "Cancel")}
            </.button>
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  attr :triggered_manually?, :boolean, required: true

  defp trigger_badge(%{triggered_manually?: true} = assigns) do
    ~H"""
    <.badge variant="muted" size="sm">
      <:icon><Lucideicons.mouse_pointer /></:icon>
      {dgettext("admin_media_imports", "Manual")}
    </.badge>
    """
  end

  defp trigger_badge(%{triggered_manually?: false} = assigns) do
    ~H"""
    <.badge variant="muted" size="sm">
      <:icon><Lucideicons.calendar /></:icon>
      {dgettext("admin_media_imports", "Scheduled")}
    </.badge>
    """
  end

  defp duration(%ImportRun{finished_at: nil}), do: "—"

  defp duration(%ImportRun{inserted_at: started, finished_at: finished}) do
    seconds = DateTime.diff(finished, started, :second)
    format_duration(seconds)
  end

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining = rem(seconds, 60)
    "#{minutes}m #{String.pad_leading(Integer.to_string(remaining), 2, "0")}s"
  end
end
