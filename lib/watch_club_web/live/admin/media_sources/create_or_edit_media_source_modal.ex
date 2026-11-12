defmodule WatchClubWeb.Admin.MediaSources.CreateOrEditMediaSourceModal do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Media.MediaTypeBadge

  attr :form, Phoenix.HTML.Form, required: true
  attr :mode, :atom, required: true, values: [:create, :edit]
  attr :media_source, Source, default: nil

  def create_or_edit_media_source_modal(assigns) do
    assigns = assign(assigns, mode_copy(assigns.mode))

    ~H"""
    <.modal id="create-or-edit-media-source-modal" on_close={JS.push("close_modals")}>
      <:title>{@title}</:title>
      <:description :if={@description}>{@description}</:description>

      <.form
        for={@form}
        id="create-or-edit-media-source-form"
        phx-change="validate_configure_media_source"
        phx-submit="submit_configure_media_source"
      >
        <.media_type_field form={@form} mode={@mode} media_source={@media_source} />

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
              "Watch Club looks for files of this type in the folder and all its subfolders."
            )}
          </:hint>
        </.field>

        <:action>
          <.button
            id="cancel-create-or-edit-media-source-button"
            type="button"
            variant="secondary"
            data-modal-close
          >
            {dgettext("default", "Cancel")}
          </.button>
          <.button id={"#{@mode}-media-source-submit-button"} type="submit">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :mode, :atom, required: true
  attr :media_source, Source, default: nil

  defp media_type_field(assigns) do
    assigns =
      assign(assigns,
        media_type_value:
          case assigns.mode do
            :create -> assigns.form[:media_type].value
            :edit -> assigns.media_source.media_type
          end,
        locked_message: dgettext("admin_media_imports", "You can't change the media type later.")
      )

    ~H"""
    <.field field={@form[:media_type]} label={dgettext("admin_media_imports", "Media type")}>
      <:control>
        <.radio_group
          field={@form[:media_type]}
          value={@media_type_value}
          variant="card"
          class="grid grid-cols-1 gap-related sm:grid-cols-2"
        >
          <:item
            :for={media_type <- MediaType.values()}
            value={to_string(media_type)}
            disabled={@mode == :edit}
            tooltip={@mode == :edit && @locked_message}
            class="grid grid-cols-[auto_1fr_auto] items-center gap-related p-group"
          >
            <.media_type_badge media_type={media_type} />
            <Lucideicons.check class="size-icon-sm text-accent opacity-0 transition-opacity group-has-checked/radio-card:opacity-100" />
          </:item>
        </.radio_group>
      </:control>
    </.field>
    """
  end

  defp mode_copy(:create) do
    %{
      title: dgettext("admin_media_imports", "Configure media source"),
      description:
        dgettext(
          "admin_media_imports",
          "Choose what to import from your filesystem."
        ),
      submit_label: dgettext("admin_media_imports", "Create media source")
    }
  end

  defp mode_copy(:edit) do
    %{
      title: dgettext("admin_media_imports", "Edit media source"),
      description: nil,
      submit_label: dgettext("admin_media_imports", "Save changes")
    }
  end
end
