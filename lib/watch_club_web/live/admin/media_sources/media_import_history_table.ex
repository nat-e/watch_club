defmodule WatchClubWeb.Admin.MediaSources.MediaImportHistoryTable do
  @moduledoc """
  History table of `Media Imports` for one `Media Source`.

  Columns: Status, the Files it processed with their outcomes, Started, Duration and Trigger.
  Files comes second, so narrow screens show it without scrolling. Duration is rendered as `—`
  for in-progress Media Imports because there is no finished timestamp yet.

  Load each Media Import's `processed_file_count`.
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
          <.table_head>{dgettext("admin_media_imports", "Files")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Started")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Duration")}</.table_head>
          <.table_head>{dgettext("admin_media_imports", "Trigger")}</.table_head>
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
          <.table_cell>
            <.files media_import={media_import} locale={@locale} />
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
  attr :locale, :atom, required: true

  # Which files it processes, how far it got, and their outcomes
  defp files(assigns) do
    ~H"""
    <.stack space="related" class="items-start">
      <.badge variant="muted" size="sm">
        {files_to_process_label(@media_import.files_to_process)}
      </.badge>
      <span
        :if={@media_import.status == :processing and is_nil(@media_import.file_count)}
        class="text-text-muted"
      >
        {dgettext("admin_media_imports", "Finding files…")}
      </span>
      <span :if={@media_import.file_count == 0} class="text-text-muted">
        {dgettext("admin_media_imports", "No files to process")}
      </span>
      <.stack
        :if={
          @media_import.status in [:processing, :cancelled] and
            @media_import.file_count not in [nil, 0]
        }
        space="tight"
        class="min-w-32"
      >
        <span class="text-text-muted tabular-nums">
          {dngettext(
            "admin_media_imports",
            "%{processed} of %{total} file",
            "%{processed} of %{total} files",
            @media_import.file_count,
            processed: number!(@media_import.processed_file_count, @locale),
            total: number!(@media_import.file_count, @locale)
          )}
        </span>
        <%!-- A job run again after a crash between its count and Oban's ack counts a file twice --%>
        <.progress_bar
          :if={@media_import.status == :processing}
          percent={min(100 * @media_import.processed_file_count / @media_import.file_count, 100)}
        />
      </.stack>
      <.stack
        :if={@media_import.processed_file_count > 0}
        as="ul"
        space="none"
        class="items-start tabular-nums"
      >
        <li :if={@media_import.matched_file_count > 0}>
          {dngettext(
            "admin_media_imports",
            "%{number} matched",
            "%{number} matched",
            @media_import.matched_file_count,
            number: number!(@media_import.matched_file_count, @locale)
          )}
        </li>
        <li :if={@media_import.unmatched_file_count > 0}>
          <.link
            navigate={~p"/admin/media?unmatched=true"}
            title={dgettext("admin_media_imports", "See every unmatched file")}
            class="underline decoration-text-subtle underline-offset-4 hover:decoration-text"
          >
            {dngettext(
              "admin_media_imports",
              "%{number} unmatched",
              "%{number} unmatched",
              @media_import.unmatched_file_count,
              number: number!(@media_import.unmatched_file_count, @locale)
            )}
          </.link>
        </li>
        <li :if={@media_import.unreadable_file_count > 0} class="text-text-muted">
          {dngettext(
            "admin_media_imports",
            "%{number} unreadable",
            "%{number} unreadable",
            @media_import.unreadable_file_count,
            number: number!(@media_import.unreadable_file_count, @locale)
          )}
        </li>
        <li :if={@media_import.failed_file_count > 0} class="text-danger">
          {dngettext(
            "admin_media_imports",
            "%{number} failed",
            "%{number} failed",
            @media_import.failed_file_count,
            number: number!(@media_import.failed_file_count, @locale)
          )}
        </li>
      </.stack>
    </.stack>
    """
  end

  defp number!(count, locale),
    do: WatchClub.Cldr.Number.to_string!(count, locale: UserLocale.to_cldr_locale_name(locale))

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
