defmodule WatchClubWeb.Admin.MediaImports.CreateOrEditImportModal do
  @moduledoc """
  Modal that creates a new `Media Import Configuration` or edits the filesystem
  path of an existing one. Mirrors the create-or-edit pattern from
  `WatchClubWeb.Clubs.Settings.Libraries.CreateOrEditLibraryModal`.

  In `:edit` mode the media type is shown read-only because the domain forbids
  editing it after creation.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.MediaTypeIcon

  alias WatchClub.Media.{ImportConfiguration, MediaType}

  attr :form, Phoenix.HTML.Form, required: true
  attr :mode, :atom, required: true, values: [:create, :edit]
  attr :configuration, ImportConfiguration, default: nil

  def create_or_edit_import_modal(assigns) do
    assigns = assign(assigns, mode_copy(assigns.mode))

    ~H"""
    <.modal id="create-or-edit-import-modal" on_close={JS.push("close_modals")}>
      <:title>{@title}</:title>
      <:description :if={@description}>{@description}</:description>

      <.form
        for={@form}
        id="create-or-edit-import-form"
        phx-change="validate_configure_import"
        phx-submit="submit_configure_import"
      >
        <.media_type_field form={@form} mode={@mode} configuration={@configuration} />

        <.field
          field={@form[:filesystem_path]}
          label={dgettext("admin_media_imports", "Directory")}
          type="text"
          input_class="font-mono"
          placeholder="/media/movies"
        >
          <:hint>
            {dgettext(
              "admin_media_imports",
              "The directory and all its sub-directories will be scanned for media matching the selected type."
            )}
          </:hint>
        </.field>

        <:action>
          <.button
            id="cancel-create-or-edit-import-button"
            type="button"
            variant="secondary"
            data-modal-close
          >
            {dgettext("default", "Cancel")}
          </.button>
          <.button id={"#{@mode}-import-submit-button"} type="submit">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :mode, :atom, required: true
  attr :configuration, ImportConfiguration, default: nil

  defp media_type_field(assigns) do
    assigns =
      assign(assigns,
        media_type_value:
          case assigns.mode do
            :create -> assigns.form[:media_type].value
            :edit -> assigns.configuration.media_type
          end,
        locked_message:
          dgettext("admin_media_imports", "Media type cannot be changed after creation.")
      )

    ~H"""
    <.field field={@form[:media_type]} label={dgettext("admin_media_imports", "Media type")}>
      <:control>
        <.radio_group
          field={@form[:media_type]}
          value={@media_type_value}
          class="grid grid-cols-1 gap-related sm:grid-cols-2"
        >
          <:item
            :for={media_type <- MediaType.values()}
            value={to_string(media_type)}
            disabled={@mode == :edit}
            tooltip={@mode == :edit && @locked_message}
            class={[
              "group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-related rounded-control border border-border bg-surface-inset p-group transition-colors has-[:checked]:border-accent has-[:checked]:bg-surface-selected has-[:focus-visible]:border-border-focus has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus-ring has-[:disabled]:cursor-not-allowed has-[:disabled]:opacity-50 [&>[data-slot=radio-group-item]]:sr-only",
              @mode == :create && "hover:bg-surface-hover"
            ]}
          >
            <.media_type_icon media_type={media_type} class="size-icon text-text-muted" />
            <span class="font-medium">{MediaType.translated_plural_label(media_type)}</span>
            <Lucideicons.check class="size-icon-sm text-accent opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
          </:item>
        </.radio_group>
      </:control>
    </.field>
    """
  end

  defp mode_copy(:create) do
    %{
      title: dgettext("admin_media_imports", "Configure import"),
      description:
        dgettext(
          "admin_media_imports",
          "Configure what media should be imported from your filesystem."
        ),
      submit_label: dgettext("admin_media_imports", "Create Import")
    }
  end

  defp mode_copy(:edit) do
    %{
      title: dgettext("admin_media_imports", "Edit import"),
      description: nil,
      submit_label: dgettext("admin_media_imports", "Save changes")
    }
  end
end
