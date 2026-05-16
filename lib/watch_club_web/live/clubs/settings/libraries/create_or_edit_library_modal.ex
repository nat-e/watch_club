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
                "Add a new library to this club. Choose one or more accepted content types."
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

    assigns =
      assign(
        assigns,
        :removed_content_types,
        removed_content_types(assigns.library, assigns.form[:accepted_content_types].value)
      )

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

        <.accepted_content_types_field form={@form} content_types={@content_types} />

        <.alert :if={@removed_content_types != []} variant="warning">
          <:icon><Lucideicons.triangle_alert /></:icon>
          <:title>{dgettext("clubs", "Accepted content types removed")}</:title>
          <p>
            {dgettext(
              "clubs",
              "Saving will remove any existing library items of %{content_types} from this library.",
              content_types: removed_content_type_labels(@removed_content_types)
            )}
          </p>
          <p>{dgettext("clubs", "The underlying content records will not be deleted.")}</p>
        </.alert>

        <:action>
          <.button type="button" variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button type="submit">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true

  defp accepted_content_types_field(assigns) do
    ~H"""
    <.field field={@form[:accepted_content_types]} label={dgettext("clubs", "Content types")}>
      <:hint>
        {dgettext(
          "clubs",
          "Select which content types are allowed in this library. Members will only be able to add content of these types to the library"
        )}
      </:hint>
      <:control>
        <div class="grid grid-cols-1 gap-related sm:grid-cols-3">
          <label
            :for={content_type <- @content_types}
            class="group/checkbox-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-related rounded-control border border-border bg-surface-inset p-group transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected"
          >
            <input
              type="checkbox"
              name={@form[:accepted_content_types].name <> "[]"}
              value={to_string(content_type)}
              checked={
                accepted_content_type_checked?(@form[:accepted_content_types].value, content_type)
              }
              class="sr-only"
            />
            <.content_type_icon type={content_type} class="size-icon text-text-muted" />
            <span class="font-medium">{ContentType.translated_label(content_type)}</span>
            <Lucideicons.check class="size-icon-sm text-primary opacity-0 transition-opacity group-has-[:checked]/checkbox-card:opacity-100" />
          </label>
        </div>
      </:control>
    </.field>
    """
  end

  defp accepted_content_type_checked?(value, content_type) when is_list(value) do
    to_string(content_type) in Enum.map(value, &to_string/1)
  end

  defp accepted_content_type_checked?(value, content_type),
    do: to_string(value) == to_string(content_type)

  defp removed_content_type_labels(content_types) do
    content_types
    |> Enum.map(&ContentType.translated_label/1)
    |> Enum.join(", ")
  end

  defp removed_content_types(nil, _accepted_content_type_value), do: []

  defp removed_content_types(%Library{} = library, accepted_content_type_value) do
    library.accepted_content_types --
      accepted_content_types_from_value(accepted_content_type_value)
  end

  defp accepted_content_types_from_value(value) do
    value
    |> List.wrap()
    |> Enum.flat_map(fn value ->
      case ContentType.cast_input(value, []) do
        {:ok, content_type} -> [content_type]
        _ -> []
      end
    end)
  end

  defp push_to_target(event, nil), do: JS.push(event)
  defp push_to_target(event, target), do: JS.push(event, target: target)
end
