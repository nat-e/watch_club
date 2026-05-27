defmodule WatchClubWeb.Admin.MediaSources.MediaSourceCard do
  @moduledoc """
  Card for a `Media Source` on the Media Sources list page. Top row
  carries the source-type mark, name, media-type pill, source identifier
  (path or URL+root), and a single ellipsis menu. Bottom row carries the
  schedule placeholder and the last-import status.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaSources.LastImportSummary
  import WatchClubWeb.Components.Media.MediaTypeIcon
  import WatchClubWeb.Components.Media.SourceIdentifier
  import WatchClubWeb.Components.Media.SourceTypeIcon

  alias WatchClub.Media.{MediaImport, MediaSource}

  attr :media_source, MediaSource, required: true
  attr :locale, :atom, required: true

  def media_source_card(assigns) do
    assigns =
      assign(
        assigns,
        :processing?,
        match?(%MediaImport{status: :processing}, assigns.media_source.latest_import)
      )

    ~H"""
    <.card
      padding="group"
      surface="raised"
      shadow={false}
      class="flex flex-col gap-group"
    >
      <div class="flex items-start gap-related">
        <.stack space="tight" class="min-w-0 flex-1">
          <.cluster space="related" class="min-w-0">
            <.link
              navigate={~p"/admin/media/sources/#{@media_source.id}/history"}
              class="truncate text-base font-semibold tracking-tight text-text outline-none hover:text-text"
            >
              {@media_source.name}
            </.link>
            <.media_type_pill media_type={@media_source.media_type} />
          </.cluster>

          <.source_identifier media_source={@media_source} />
        </.stack>

        <.dropdown_menu id={"media-source-actions-#{@media_source.id}"}>
          <:trigger>
            <.button
              id={"media-source-actions-trigger-#{@media_source.id}"}
              variant="ghost"
              size="icon-sm"
              class="text-text-muted hover:text-text"
              aria-label={
                dgettext("admin_media_imports", "Actions for %{label}", label: @media_source.name)
              }
            >
              <Lucideicons.ellipsis_vertical />
            </.button>
          </:trigger>

          <.dropdown_menu_item
            :if={@media_source.source_type == :filesystem}
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
      </div>

      <div class="flex items-center justify-between gap-related border-t border-border-subtle pt-group">
        <div class="text-sm text-text-muted">
          <span class="text-text-subtle">
            {dgettext("admin_media_imports", "Schedule")}
          </span>
          <span class="ml-tight text-text">
            {dgettext("admin_media_imports", "Manual only")}
          </span>
        </div>
        <.last_import_summary latest_import={@media_source.latest_import} locale={@locale} />
      </div>
    </.card>
    """
  end

  attr :media_type, :atom, required: true

  defp media_type_pill(assigns) do
    ~H"""
    <span class="inline-flex shrink-0 items-center gap-tight rounded-full border border-border-subtle bg-surface-inset px-related py-0.5 text-xs font-medium text-text-muted">
      <.media_type_icon media_type={@media_type} class="size-icon-sm" />
      {WatchClub.Media.MediaType.translated_plural_label(@media_type)}
    </span>
    """
  end
end
