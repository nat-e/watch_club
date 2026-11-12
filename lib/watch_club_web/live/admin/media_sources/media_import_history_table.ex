defmodule WatchClubWeb.Admin.MediaSources.MediaImportHistoryTable do
  @moduledoc """
  History table of `Media Imports` for one `Media Source`.

  Columns: Status, Started, Duration, Trigger, and the Files it processed, with their outcomes.
  Duration is rendered as `—` for in-progress Media Imports because there is
  no finished timestamp yet.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaSources.RunStatusBadge

  attr :imports, :list, required: true
  attr :locale, :atom, required: true

  def media_import_history_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>{dgettext("admin_media_imports", "Status")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Started")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Duration")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Trigger")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Files")}</.table_head>
          <.table_head class="w-0">
            <span class="sr-only">{dgettext("admin_media_imports", "Actions")}</span>
          </.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row :for={media_import <- @imports}>
          <.table_cell>
            <.run_status_badge status={media_import.status} />
          </.table_cell>
          <.table_cell class="text-text-muted">
            {Time.relative_from_now(media_import.inserted_at, @locale)}
          </.table_cell>
          <.table_cell class="text-text-muted">
            {duration(media_import)}
          </.table_cell>
          <.table_cell>
            <.trigger_badge triggered_manually?={media_import.triggered_manually?} />
          </.table_cell>
          <.table_cell>
            <div class="flex flex-col items-start gap-tight">
              <.badge variant="muted" size="sm">
                {files_to_process_label(media_import.files_to_process)}
              </.badge>
              <.file_counts media_import={media_import} />
            </div>
          </.table_cell>
          <.table_cell class="text-end!">
            <.button
              :if={media_import.status == :processing}
              id={"cancel-media-import-#{media_import.id}"}
              variant="secondary"
              class="text-text-muted hover:text-text"
              phx-click="cancel_media_import"
              phx-value-id={media_import.id}
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

  attr :media_import, Import, required: true

  defp file_counts(%{media_import: %Import{file_count: nil, status: :processing}} = assigns) do
    ~H"""
    <span class="text-text-muted">{dgettext("admin_media_imports", "Finding files…")}</span>
    """
  end

  # The scan failed or was cancelled, or the Media Import ran before files were counted
  defp file_counts(%{media_import: %Import{file_count: nil}} = assigns), do: ~H""

  defp file_counts(%{media_import: %Import{file_count: 0}} = assigns) do
    ~H"""
    <span class="text-text-muted">{dgettext("admin_media_imports", "No files to process")}</span>
    """
  end

  defp file_counts(%{media_import: %Import{status: :processing} = media_import} = assigns) do
    assigns =
      assign(
        assigns,
        :processed,
        media_import.matched_file_count + media_import.unmatched_file_count +
          media_import.unreadable_file_count
      )

    ~H"""
    <div class="flex min-w-32 flex-col gap-tight">
      <span class="text-text-muted tabular-nums">
        {dngettext(
          "admin_media_imports",
          "%{processed} of %{count} file",
          "%{processed} of %{count} files",
          @media_import.file_count,
          processed: @processed
        )}
      </span>
      <.progress_bar percent={100 * @processed / @media_import.file_count} />
    </div>
    """
  end

  # A cancelled Media Import may have processed no file
  defp file_counts(
         %{
           media_import: %Import{
             matched_file_count: 0,
             unmatched_file_count: 0,
             unreadable_file_count: 0,
             failed_file_count: 0
           }
         } = assigns
       ),
       do: ~H""

  defp file_counts(assigns) do
    ~H"""
    <div class="flex flex-col items-start whitespace-nowrap tabular-nums">
      <span :if={@media_import.matched_file_count > 0}>
        {dngettext(
          "admin_media_imports",
          "%{count} matched",
          "%{count} matched",
          @media_import.matched_file_count
        )}
      </span>
      <.link
        :if={@media_import.unmatched_file_count > 0}
        navigate={~p"/admin/media?unmatched=true"}
        class="underline underline-offset-4"
      >
        {dngettext(
          "admin_media_imports",
          "%{count} unmatched",
          "%{count} unmatched",
          @media_import.unmatched_file_count
        )}
      </.link>
      <span :if={@media_import.unreadable_file_count > 0} class="text-text-muted">
        {dngettext(
          "admin_media_imports",
          "%{count} unreadable",
          "%{count} unreadable",
          @media_import.unreadable_file_count
        )}
      </span>
      <span :if={@media_import.failed_file_count > 0} class="text-danger">
        {dngettext(
          "admin_media_imports",
          "%{count} failed",
          "%{count} failed",
          @media_import.failed_file_count
        )}
      </span>
    </div>
    """
  end

  defp files_to_process_label(:new), do: dgettext("admin_media_imports", "New")

  defp files_to_process_label(:new_and_unmatched),
    do: dgettext("admin_media_imports", "New and unmatched")

  defp files_to_process_label(:all), do: dgettext("admin_media_imports", "All")

  defp duration(%Import{finished_at: nil}), do: "—"

  defp duration(%Import{inserted_at: started, finished_at: finished}) do
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
