defmodule WatchClubWeb.Admin.MediaImports.ConfigurationCard do
  @moduledoc """
  Compact one-line-ish card for a `Media Import Configuration` on the imports
  list page. Layout mirrors the club library list item — a three-column grid of
  icon · content · actions — with the content column stacking the plural-label
  link above the path chip + last-run summary.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaImports.LastRunSummary
  import WatchClubWeb.Components.Media.{FilesystemPath, MediaTypeIcon}

  alias WatchClub.Media.{ImportConfiguration, ImportRun, MediaType}

  attr :configuration, ImportConfiguration, required: true
  attr :locale, :atom, required: true

  def configuration_card(assigns) do
    assigns = assign(assigns, :processing?, processing?(assigns.configuration.latest_run))

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
            <.media_type_icon media_type={@configuration.media_type} />
          </span>
          <.link
            navigate={~p"/admin/media/imports/#{@configuration.id}/history"}
            class="truncate text-base font-semibold tracking-tight text-text outline-none hover:text-text"
          >
            {MediaType.translated_plural_label(@configuration.media_type)}
          </.link>
          <.filesystem_path path={@configuration.filesystem_path} />
        </.cluster>

        <.last_run_summary latest_run={@configuration.latest_run} locale={@locale} />
      </.stack>

      <.dropdown_menu id={"configuration-actions-#{@configuration.id}"}>
        <:trigger>
          <.button
            id={"configuration-actions-trigger-#{@configuration.id}"}
            variant="ghost"
            size="icon-sm"
            class="text-text-muted hover:text-text"
            aria-label={
              dgettext("admin_media_imports", "Actions for %{label}",
                label: MediaType.translated_plural_label(@configuration.media_type)
              )
            }
          >
            <Lucideicons.ellipsis_vertical />
          </.button>
        </:trigger>

        <.dropdown_menu_item
          id={"run-now-#{@configuration.id}"}
          disabled={@processing?}
          phx-click="open_run_import_modal"
          phx-value-id={@configuration.id}
        >
          <Lucideicons.loader_circle :if={@processing?} class="animate-spin" />
          <Lucideicons.play :if={!@processing?} />
          {dgettext("admin_media_imports", "Run now")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id={"configuration-history-#{@configuration.id}"}
          navigate={~p"/admin/media/imports/#{@configuration.id}/history"}
        >
          <Lucideicons.clock />
          {dgettext("admin_media_imports", "View history")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id={"configuration-edit-#{@configuration.id}"}
          phx-click="open_edit_import_modal"
          phx-value-id={@configuration.id}
        >
          <Lucideicons.pencil />
          {dgettext("admin_media_imports", "Edit")}
        </.dropdown_menu_item>
        <.dropdown_menu_separator />
        <.dropdown_menu_item
          id={"configuration-delete-#{@configuration.id}"}
          variant="destructive"
          phx-click="open_delete_modal"
          phx-value-id={@configuration.id}
        >
          <Lucideicons.trash />
          {dgettext("admin_media_imports", "Delete…")}
        </.dropdown_menu_item>
      </.dropdown_menu>
    </.card>
    """
  end

  defp processing?(%ImportRun{status: :processing}), do: true
  defp processing?(_), do: false
end
