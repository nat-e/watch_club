defmodule WatchClubWeb.ClubsLive.LibraryManagementComponents do
  @moduledoc """
  Presentational components for club library management.
  """
  use WatchClubWeb, :component
  use WatchClubWeb.Components

  attr :target, :any, default: nil

  def libraries_empty_state(assigns) do
    ~H"""
    <.empty class="py-section">
      <:icon>
        <Lucideicons.library />
      </:icon>
      <:title>{dgettext("clubs", "No libraries yet")}</:title>
      <:description>
        {dgettext(
          "clubs",
          "Create libraries to add movies, TV shows, or books to your club."
        )}
      </:description>
      <.button phx-click="open_create_library_modal" phx-target={@target}>
        <Lucideicons.plus />
        {dgettext("clubs", "Create library")}
      </.button>
    </.empty>
    """
  end

  attr :libraries, :list, required: true
  attr :target, :any, default: nil

  def library_list(assigns) do
    ~H"""
    <.reorderable_list
      id="club-libraries-list"
      items={@libraries}
      item_id={:id}
      event="reorder_libraries"
      target={@target}
      class="grid gap-related"
      item_class="group grid gap-group rounded-card border border-border bg-surface-raised p-group shadow-xs transition-colors hover:bg-surface-hover sm:grid-cols-[auto_auto_minmax(0,1fr)_auto] sm:items-center"
    >
      <:item :let={{library, _index}}>
        <.library_list_item library={library} target={@target} />
      </:item>
    </.reorderable_list>
    """
  end

  attr :library, Library, required: true
  attr :target, :any, default: nil

  def library_list_item(assigns) do
    ~H"""
    <button
      type="button"
      data-sortable-handle
      class="inline-flex size-control-sm shrink-0 cursor-grab items-center justify-center rounded-control text-text-muted hover:bg-surface-hover hover:text-text active:cursor-grabbing"
      aria-label={dgettext("clubs", "Drag to reorder")}
    >
      <Lucideicons.grip_vertical class="size-icon" />
    </button>

    <button
      type="button"
      class="inline-grid size-control-lg shrink-0 place-items-center rounded-control border border-border bg-surface-inset text-text-muted transition-colors hover:bg-surface-hover hover:text-text focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40"
      phx-click="open_icon_picker"
      phx-target={@target}
      phx-value-library_id={@library.id}
      aria-label={dgettext("clubs", "Change %{library_name} icon", library_name: @library.name)}
    >
      <.library_icon library={@library} class="size-icon-lg" />
    </button>

    <div class="grid min-w-0 gap-tight">
      <h3 class="truncate text-base font-semibold">{@library.name}</h3>
      <div class="flex flex-wrap gap-tight">
        <.accepted_content_type_badge
          :for={content_type <- ContentType.library_display_order()}
          :if={content_type in @library.accepted_content_types}
          content_type={content_type}
        />
      </div>
    </div>

    <.dropdown_menu class="justify-self-start sm:justify-self-end">
      <:trigger>
        <.button
          variant="ghost"
          size="icon-sm"
          class="text-text-muted hover:text-text"
          aria-label={dgettext("clubs", "Library actions")}
        >
          <Lucideicons.ellipsis_vertical />
        </.button>
      </:trigger>

      <.dropdown_menu_item
        phx-click="open_edit_library_modal"
        phx-target={@target}
        phx-value-library_id={@library.id}
      >
        <Lucideicons.pencil />{dgettext("clubs", "Edit Library")}
      </.dropdown_menu_item>
      <.dropdown_menu_item
        variant="destructive"
        phx-click="open_delete_library_modal"
        phx-target={@target}
        phx-value-library_id={@library.id}
      >
        <Lucideicons.trash_2 />{dgettext("clubs", "Delete Library")}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end

  attr :content_type, :atom, required: true

  defp accepted_content_type_badge(assigns) do
    ~H"""
    <.badge variant="secondary" class="whitespace-nowrap">
      <:icon><.content_type_icon type={@content_type} /></:icon>
      {ContentType.translated_label(@content_type)}
    </.badge>
    """
  end

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :library, Library, default: nil
  attr :mode, :atom, required: true
  attr :target, :any, default: nil

  def library_form_modal(assigns) do
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
      <:hint>{dgettext("clubs", "Select which content types are allowed in this library. Members will only be able to add content of these types to the library")}</:hint>
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

  attr :library, Library, required: true
  attr :target, :any, default: nil

  def delete_library_modal(assigns) do
    ~H"""
    <.modal id="delete-library-modal" on_close={push_to_target("close_modals", @target)}>
      <:title>{dgettext("clubs", "Delete %{library_name}?", library_name: @library.name)}</:title>
      <p>
        {dgettext("clubs", "This will remove the library from the club.")}
      </p>
      <p class="text-text-muted text-sm">
        {dgettext(
          "clubs",
          "The underlying content records will not be deleted."
        )}
      </p>
      <:footer>
        <.button type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button
          variant="danger"
          phx-click="confirm_delete_library"
          phx-target={@target}
        >
          {dgettext("clubs", "Delete library")}
        </.button>
      </:footer>
    </.modal>
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
