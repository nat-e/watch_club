defmodule WatchClubWeb.Components.Lists.ListDialogs.CreateOrEditListModal do
  @moduledoc """
  Create/edit modal for a user's List. The name is edited inline next to an
  icon button that opens the shared icon picker.
  """
  use WatchClubWeb, :component

  attr :form, Phoenix.HTML.Form, required: true
  attr :icon, :string, required: true
  attr :myself, :any, required: true

  def create_or_edit_list_modal(assigns) do
    edit? = assigns.form.source.type == :update

    assigns =
      assigns
      |> assign(
        edit?: edit?,
        title: (edit? && dgettext("lists", "Edit list")) || dgettext("lists", "Create new list"),
        submit_label: (edit? && dgettext("default", "Save")) || dgettext("default", "Create")
      )

    ~H"""
    <.modal id="list-modal" size="md" on_close={JS.push("close_modals", target: @myself)}>
      <:title>{@title}</:title>
      <:description>
        {dgettext(
          "lists",
          "Create a private content List to keep track of what you want to watch, read, ..."
        )}
      </:description>

      <.form
        for={@form}
        id="list-form"
        phx-change="validate_list_form"
        phx-submit="submit_list_form"
        phx-target={@myself}
      >
        <%!-- The icon is chosen through the picker; carry it with the form on submit. --%>
        <input type="hidden" name={@form[:icon].name} value={@icon} />

        <.field field={@form[:name]} label={dgettext("lists", "List name")}>
          <:control>
            <div class="flex items-center gap-related">
              <.button
                id="list-icon-picker-button"
                type="button"
                variant="secondary"
                size="icon"
                class="shrink-0"
                phx-click={JS.push("open_list_icon_picker", target: @myself)}
                aria-label={dgettext("lists", "Change list icon")}
              >
                <.lucide_icon name={@icon} class="size-icon-lg" />
              </.button>
              <.input
                field={@form[:name]}
                class="flex-1"
                phx-debounce="blur"
                placeholder={dgettext("lists", "My list")}
                phx-mounted={JS.focus()}
              />
            </div>
          </:control>
        </.field>

        <:action>
          <.button id="cancel-list-button" type="button" variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button id="list-submit-button" type="submit">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
