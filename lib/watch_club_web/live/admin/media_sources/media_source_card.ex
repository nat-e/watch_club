defmodule WatchClubWeb.Admin.MediaSources.MediaSourceCard do
  @moduledoc """
  Card for a `Media Source` on the Media Sources list page. Top row
  carries the source-type mark, name, media-type pill, source identifier
  (path or URL+root), and a single ellipsis menu. Bottom row carries the
  schedule placeholder and the last-import status.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaSources.LastImportSummary
  import WatchClubWeb.Components.Media.MediaTypeBadge
  import WatchClubWeb.Components.Media.SourceIdentifier

  attr :media_source, Source, required: true
  attr :locale, :atom, required: true

  def media_source_card(assigns) do
    assigns =
      assign(
        assigns,
        :processing?,
        match?(%Import{status: :processing}, assigns.media_source.latest_import)
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
          <.link
            navigate={~p"/admin/media/sources/#{@media_source.id}/history"}
            class="truncate text-base font-semibold tracking-tight text-text outline-none hover:text-text"
          >
            {@media_source.name}
          </.link>
          <.cluster space="related" class="min-w-0">
            <.media_type_badge media_type={@media_source.media_type} />
            <.source_identifier media_source={@media_source} />
          </.cluster>
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
end
