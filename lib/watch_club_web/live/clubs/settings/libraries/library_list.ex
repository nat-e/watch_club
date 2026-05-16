defmodule WatchClubWeb.Clubs.Settings.Libraries.LibraryList do
  @moduledoc """
  Library list for the club settings page.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeIcon
  import WatchClubWeb.Components.Libraries.LibraryIcon

  attr :libraries, :list, required: true
  attr :target, :any, default: nil

  def library_list(%{libraries: []} = assigns) do
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

  defp library_list_item(assigns) do
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
end
