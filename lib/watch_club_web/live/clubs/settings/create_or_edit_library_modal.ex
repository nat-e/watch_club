defmodule WatchClubWeb.Clubs.Settings.CreateOrEditLibraryModal do
  @moduledoc """
  Create/edit library modal for the club settings page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true

  def create_or_edit_library_modal(assigns) do
    edit? = assigns.form.source.type == :update

    assigns =
      assigns
      |> assign(
        edit?: edit?,
        title:
          (edit? && dgettext("clubs", "Edit Library")) || dgettext("clubs", "Create library"),
        submit_label: (edit? && dgettext("clubs", "Save")) || dgettext("clubs", "Create")
      )

    ~H"""
    <.modal id="library-modal" on_close={JS.push("close_modals")}>
      <:title>{@title}</:title>
      <:description :if={!@edit?}>
        {dgettext(
          "clubs",
          "Add a new library to this club. Choose which content type it will contain."
        )}
      </:description>
      <.form
        for={@form}
        id="library-form"
        phx-change="validate_library_form"
        phx-submit="submit_library_form"
      >
        <.field field={@form[:name]} label={dgettext("clubs", "Library name")} type="text" />

        <.field field={@form[:content_type]} label={dgettext("clubs", "Content type")}>
          <:hint>
            {dgettext(
              "clubs",
              "Users will only be able to add this type of content to the library"
            )}
          </:hint>
          <:control>
            <.radio_group
              field={@form[:content_type]}
              class="grid grid-cols-1 gap-related sm:grid-cols-2"
            >
              <:item
                :for={content_type <- @content_types}
                value={to_string(content_type)}
                disabled={@edit?}
                tooltip={
                  @edit? &&
                    dgettext("clubs", "A library's content type cannot be changed after creation.")
                }
                class={[
                  "group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-related rounded-md border border-border bg-surface-inset p-group transition-colors has-checked:border-accent has-checked:bg-surface-selected has-focus-visible:border-border-focus has-focus-visible:ring-2 has-focus-visible:ring-focus-ring has-disabled:cursor-not-allowed has-disabled:opacity-50 *:data-[slot=radio-group-item]:sr-only",
                  !@edit? && "hover:bg-surface-hover"
                ]}
              >
                <.content_type_icon type={content_type} class="size-icon text-text-muted" />
                <span class="font-medium">{ContentType.translated_label(content_type)}</span>
                <Lucideicons.check class="size-icon-sm text-accent opacity-0 transition-opacity group-has-checked/radio-card:opacity-100" />
              </:item>
            </.radio_group>
          </:control>
        </.field>

        <:action>
          <.button
            id="cancel-library-button"
            type="button"
            variant="secondary"
            data-modal-close
          >
            {dgettext("default", "Cancel")}
          </.button>
          <.button id="library-submit-button" type="submit">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
