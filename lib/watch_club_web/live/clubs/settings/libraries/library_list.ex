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
      <.button
        id="empty-create-library-button"
        phx-click="open_create_library_modal"
        phx-target={@target}
      >
        <Lucideicons.plus />
        {dgettext("clubs", "Create library")}
      </.button>
    </.empty>
    """
  end

  def library_list(assigns) do
    ~H"""
    <%!--
      Club libraries are intentionally low-cardinality, and reordering needs the
      complete ordered list, so this deliberately uses a regular list assign.
    --%>
    <.reorderable_list
      id="club-libraries-list"
      items={@libraries}
      item_id={:id}
      event="reorder_libraries"
      target={@target}
      class="flex flex-col gap-related"
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
    <.card
      as="div"
      surface="raised"
      class="grid gap-group sm:grid-cols-[auto_auto_minmax(0,1fr)_auto] sm:items-center"
    >
      <.button
        id={"library-reorder-handle-#{@library.id}"}
        type="button"
        variant="ghost"
        size="icon"
        data-sortable-handle
        class="cursor-grab active:cursor-grabbing"
        aria-label={dgettext("clubs", "Drag to reorder")}
      >
        <Lucideicons.grip_vertical class="size-icon" />
      </.button>

      <.button
        id={"library-icon-picker-button-#{@library.id}"}
        type="button"
        variant="secondary"
        size="icon"
        phx-click="open_icon_picker"
        phx-target={@target}
        phx-value-library_id={@library.id}
        aria-label={dgettext("clubs", "Change %{library_name} icon", library_name: @library.name)}
      >
        <.library_icon library={@library} class="size-icon-lg" />
      </.button>

      <.stack space="tight" class="min-w-0">
        <h3 class="truncate text-base font-semibold">{@library.name}</h3>
        <div class="flex flex-wrap gap-tight">
          <.content_type_badge content_type={@library.content_type} />
        </div>
      </.stack>

      <.dropdown_menu
        id={"library-actions-#{@library.id}"}
        class="justify-self-start sm:justify-self-end"
      >
        <:trigger>
          <.button
            id={"library-actions-trigger-#{@library.id}"}
            variant="ghost"
            size="icon-sm"
            class="text-text-muted hover:text-text"
            aria-label={dgettext("clubs", "Library actions")}
          >
            <Lucideicons.ellipsis_vertical />
          </.button>
        </:trigger>

        <.dropdown_menu_item
          id={"edit-library-menu-item-#{@library.id}"}
          phx-click="open_edit_library_modal"
          phx-target={@target}
          phx-value-library_id={@library.id}
        >
          <Lucideicons.pencil />{dgettext("clubs", "Edit Library")}
        </.dropdown_menu_item>
        <.dropdown_menu_item
          id={"delete-library-menu-item-#{@library.id}"}
          variant="destructive"
          phx-click="open_delete_library_modal"
          phx-target={@target}
          phx-value-library_id={@library.id}
        >
          <Lucideicons.trash_2 />{dgettext("clubs", "Delete Library")}
        </.dropdown_menu_item>
      </.dropdown_menu>
    </.card>
    """
  end

  attr :content_type, :atom, required: true

  defp content_type_badge(assigns) do
    ~H"""
    <.badge variant="secondary" class="whitespace-nowrap">
      <:icon><.content_type_icon type={@content_type} /></:icon>
      {ContentType.translated_label(@content_type)}
    </.badge>
    """
  end
end
