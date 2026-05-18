defmodule WatchClubWeb.Clubs.Settings.Libraries.CreateOrEditLibraryModal do
  @moduledoc """
  Create/edit library modal for the club settings page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :library, Library, default: nil
  attr :mode, :atom, required: true
  attr :target, :any, default: nil

  def create_or_edit_library_modal(assigns) do
    assigns =
      case assigns.mode do
        :create ->
          assign(assigns,
            title: dgettext("clubs", "Create library"),
            description:
              dgettext(
                "clubs",
                "Add a new library to this club. Choose which content type it will contain."
              ),
            change_event: "validate_create_library",
            submit_event: "submit_create_library",
            submit_label: dgettext("clubs", "Create library")
          )

        :edit ->
          assign(assigns,
            title: dgettext("clubs", "Edit Library"),
            description: nil,
            change_event: "validate_edit_library",
            submit_event: "submit_edit_library",
            submit_label: dgettext("clubs", "Save changes")
          )
      end

    ~H"""
    <.modal id="create-or-edit-library-modal" on_close={push_to_target("close_modals", @target)}>
      <:title>{@title}</:title>
      <:description :if={@description}>{@description}</:description>
      <.form
        for={@form}
        id="create-or-edit-library-form"
        phx-change={@change_event}
        phx-submit={@submit_event}
        phx-target={@target}
      >
        <.field field={@form[:name]} label={dgettext("clubs", "Library name")} type="text" />

        <.content_type_field
          form={@form}
          library={@library}
          mode={@mode}
          content_types={@content_types}
        />

        <:action>
          <.button
            id="cancel-create-or-edit-library-button"
            type="button"
            variant="secondary"
            data-modal-close
          >
            {dgettext("default", "Cancel")}
          </.button>
          <.button id={"#{@mode}-library-submit-button"} type="submit">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :library, Library, default: nil
  attr :mode, :atom, required: true

  defp content_type_field(assigns) do
    assigns =
      assign(
        assigns,
        :content_type_value,
        case assigns.mode do
          :create -> assigns.form[:content_type].value
          :edit -> assigns.library.content_type
        end
      )

    ~H"""
    <.field field={@form[:content_type]} label={dgettext("clubs", "Content type")}>
      <:hint :if={@mode == :edit}>
        {dgettext("clubs", "A library's content type cannot be changed after creation.")}
      </:hint>
      <:control>
        <.radio_group
          field={@form[:content_type]}
          value={@content_type_value}
          class="grid grid-cols-1 gap-related sm:grid-cols-3"
        >
          <:item
            :for={content_type <- @content_types}
            value={to_string(content_type)}
            disabled={@mode == :edit}
            class={[
              "group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-related rounded-control border border-border bg-surface-inset p-group transition-colors has-[:checked]:border-accent has-[:checked]:bg-surface-selected has-[:focus-visible]:border-border-focus has-[:focus-visible]:ring-2 has-[:focus-visible]:ring-focus-ring has-[:disabled]:cursor-not-allowed has-[:disabled]:opacity-50 [&>[data-slot=radio-group-item]]:sr-only",
              @mode == :create && "hover:bg-surface-hover"
            ]}
          >
            <.content_type_icon type={content_type} class="size-icon text-text-muted" />
            <span class="font-medium">{ContentType.translated_label(content_type)}</span>
            <Lucideicons.check class="size-icon-sm text-accent opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
          </:item>
        </.radio_group>
      </:control>
    </.field>
    """
  end

  defp push_to_target(event, nil), do: JS.push(event)
  defp push_to_target(event, target), do: JS.push(event, target: target)
end
