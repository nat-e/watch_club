defmodule WatchClubWeb.ClubsLive.LibraryManagementComponents do
  @moduledoc """
  Presentational components for club library management.
  """
  use WatchClubWeb, :component
  use WatchClubWeb.Components

  attr :target, :any, default: nil

  def libraries_empty_state(assigns) do
    ~H"""
    <.empty class="border-border rounded-lg border border-dashed py-10">
      <:media variant="icon">
        <Lucideicons.library class="size-8" />
      </:media>
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
      class="flex flex-col gap-2"
      item_class="border-border bg-background group flex flex-col gap-3 rounded-lg border p-3 shadow-xs transition-colors hover:bg-muted/40 sm:flex-row sm:items-start"
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
      class="text-muted-foreground hover:text-foreground mt-1 inline-flex size-8 shrink-0 cursor-grab items-center justify-center rounded-md active:cursor-grabbing"
      aria-label={dgettext("clubs", "Drag to reorder")}
    >
      <Lucideicons.grip_vertical class="size-5" />
    </button>

    <.editable_label
      id={"library-name-#{@library.id}"}
      value={@library.name}
      event="rename_library"
      payload={%{library_id: @library.id}}
      target={@target}
      label={dgettext("clubs", "Rename library")}
      class="min-w-0 flex-1 sm:pt-1"
      text_class="truncate font-medium"
    />

    <div class="flex shrink-0 items-center gap-2 sm:pt-1">
      <.content_type_badge type={@library.content_type} />

      <.button
        variant="ghost"
        size="icon-sm"
        class="text-destructive hover:text-destructive"
        phx-click="open_delete_library_modal"
        phx-target={@target}
        phx-value-library_id={@library.id}
        aria-label={dgettext("clubs", "Delete library")}
      >
        <Lucideicons.trash_2 class="size-4" />
      </.button>
    </div>
    """
  end

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :target, :any, default: nil

  def create_library_modal(assigns) do
    ~H"""
    <.modal open={true} on_close={push_to_target("close_modals", @target)}>
      <.dialog>
        <:title>{dgettext("clubs", "Create library")}</:title>
        <:description>
          {dgettext(
            "clubs",
            "Add a new library to this club. Multiple libraries can use the same content type."
          )}
        </:description>
        <.form
          for={@form}
          id="create-library-form"
          phx-change="validate_create_library"
          phx-submit="submit_create_library"
          phx-target={@target}
          class="flex flex-col gap-6"
        >
          <.input_with_label field={@form[:name]} label={dgettext("clubs", "Library name")}>
            <.input field={@form[:name]} type="text" phx-debounce="blur" />
          </.input_with_label>

          <div class="flex flex-col gap-2">
            <.label field={@form[:content_type]}>{dgettext("clubs", "Content type")}</.label>
            <.radio_group field={@form[:content_type]} class="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <:item
                :for={content_type <- @content_types}
                value={to_string(content_type)}
                class="border-border hover:bg-muted/50 has-[:checked]:border-primary has-[:checked]:bg-primary/5 flex cursor-pointer items-start gap-3 rounded-lg border p-3"
              >
                <div class="flex flex-col gap-1">
                  <.content_type_icon type={content_type} class="size-5" />
                  <span class="font-medium">{ContentType.translated_label(content_type)}</span>
                </div>
              </:item>
            </.radio_group>
            <.field_errors field={@form[:content_type]} />
          </div>

          <div class="flex justify-end gap-2">
            <.button type="button" variant="outline" phx-click="close_modals" phx-target={@target}>
              {dgettext("default", "Cancel")}
            </.button>
            <.button type="submit">
              {dgettext("clubs", "Create library")}
            </.button>
          </div>
        </.form>
      </.dialog>
    </.modal>
    """
  end

  attr :library, Library, required: true
  attr :target, :any, default: nil

  def delete_library_modal(assigns) do
    ~H"""
    <.modal open={true} on_close={push_to_target("close_modals", @target)}>
      <.dialog>
        <:title>{dgettext("clubs", "Delete %{library_name}?", library_name: @library.name)}</:title>
        <div class="flex flex-col gap-4">
          <p>
            {dgettext("clubs", "This will remove the library from the club.")}
          </p>
          <p class="text-muted-foreground text-sm">
            {dgettext(
              "clubs",
              "The underlying content records will not be deleted."
            )}
          </p>
          <div class="flex justify-end gap-2">
            <.button type="button" variant="outline" phx-click="close_modals" phx-target={@target}>
              {dgettext("default", "Cancel")}
            </.button>
            <.button
              variant="destructive"
              phx-click="confirm_delete_library"
              phx-target={@target}
            >
              {dgettext("clubs", "Delete library")}
            </.button>
          </div>
        </div>
      </.dialog>
    </.modal>
    """
  end

  defp push_to_target(event, nil), do: JS.push(event)
  defp push_to_target(event, target), do: JS.push(event, target: target)
end
