defmodule WatchClubWeb.Admin.MediaSources.MediaSourceCard do
  @moduledoc """
  Compact one-line-ish card for a `Media Source` on the Media Sources list page.
  Layout mirrors the club library list item — a three-column grid of
  icon · content · actions — with the content column stacking the plural-label
  link above the path chip + last-import summary.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaSources.LastImportSummary
  import WatchClubWeb.Components.Media.{FilesystemPath, MediaTypeIcon}

  alias WatchClub.Media.{MediaImport, MediaSource}

  attr :media_source, MediaSource, required: true
  attr :locale, :atom, required: true

  def media_source_card(assigns) do
    assigns = assign(assigns, :processing?, processing?(assigns.media_source.latest_import))

    ~H"""
    <.card
      padding="group"
      surface="raised"
      shadow={false}
      class="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-group"
    >
      <.stack space="related" class="min-w-0">
        <.cluster space="related" class="min-w-0">
          <span class="grid size-control-md shrink-0 place-items-center rounded-control border border-border bg-surface text-text-muted">
            <.media_type_icon media_type={@media_source.media_type} />
          </span>
          <.link
            navigate={~p"/admin/media/sources/#{@media_source.id}/history"}
            class="truncate text-base font-semibold tracking-tight text-text outline-none hover:text-text"
          >
            {@media_source.name}
          </.link>
          <.filesystem_path path={@media_source.filesystem_path} />
        </.cluster>

        <.last_import_summary latest_import={@media_source.latest_import} locale={@locale} />
      </.stack>

      <.dropdown_menu id={"media-source-actions-#{@media_source.id}"}>
        <:trigger>
          <.button
            id={"media-source-actions-trigger-#{@media_source.id}"}
            variant="ghost"
            size="icon-sm"
            class="text-text-muted hover:text-text"
            aria-label={
              dgettext("admin_media_imports", "Actions for %{label}",
                label: @media_source.name
              )
            }
          >
            <Lucideicons.ellipsis_vertical />
          </.button>
        </:trigger>

        <.dropdown_menu_item
          id={"run-now-#{@media_source.id}"}
          disabled={@processing?}
          phx-click="open_run_import_modal"
          phx-value-id={@media_source.id}
        >
          <Lucideicons.loader_circle :if={@processing?} class="animate-spin" />
          <Lucideicons.play :if={!@processing?} />
          {dgettext("admin_media_imports", "Run now")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id={"media-source-history-#{@media_source.id}"}
          navigate={~p"/admin/media/sources/#{@media_source.id}/history"}
        >
          <Lucideicons.clock />
          {dgettext("admin_media_imports", "View history")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id={"media-source-edit-#{@media_source.id}"}
          phx-click="open_edit_media_source_modal"
          phx-value-id={@media_source.id}
        >
          <Lucideicons.pencil />
          {dgettext("admin_media_imports", "Edit")}
        </.dropdown_menu_item>
        <.dropdown_menu_separator />
        <.dropdown_menu_item
          id={"media-source-delete-#{@media_source.id}"}
          variant="destructive"
          phx-click="open_delete_modal"
          phx-value-id={@media_source.id}
        >
          <Lucideicons.trash />
          {dgettext("admin_media_imports", "Delete…")}
        </.dropdown_menu_item>
      </.dropdown_menu>
    </.card>
    """
  end

  defp processing?(%MediaImport{status: :processing}), do: true
  defp processing?(_), do: false
end
