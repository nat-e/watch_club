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
      item_class="group grid gap-group rounded-card border border-border bg-surface-raised p-group shadow-xs transition-colors hover:bg-surface-hover sm:grid-cols-[auto_auto_1fr_auto] sm:items-center"
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

    <div class={[
      "grid min-w-28 justify-self-start gap-tight rounded-control border p-related text-center sm:min-h-touch-target sm:place-items-center",
      @library.content_type == :movie && "border-[#FF9F6E]/40 bg-[#FF9F6E]/10 text-[#FFB38A]",
      @library.content_type == :tv_show && "border-[#7DA6FF]/40 bg-[#7DA6FF]/10 text-[#9AB8FF]",
      @library.content_type == :book && "border-[#B8D87A]/40 bg-[#B8D87A]/10 text-[#CBE88B]"
    ]}>
      <.content_type_icon type={@library.content_type} class="mx-auto size-icon-lg" />
      <span class="text-sm font-semibold leading-none">
        {ContentType.translated_label(@library.content_type)}
      </span>
    </div>

    <div class="min-w-0">
      <h3 class="truncate text-base font-semibold">{@library.name}</h3>
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
        phx-click="open_rename_library_modal"
        phx-target={@target}
        phx-value-library_id={@library.id}
      >
        <Lucideicons.pencil />{dgettext("clubs", "Rename Library")}
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

  attr :content_types, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :target, :any, default: nil

  def create_library_modal(assigns) do
    ~H"""
    <.modal id="create-library-modal" on_close={push_to_target("close_modals", @target)}>
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
      >
        <.field field={@form[:name]} label={dgettext("clubs", "Library name")} type="text" />

        <.field field={@form[:content_type]} label={dgettext("clubs", "Content type")}>
          <:control>
            <.radio_group
              field={@form[:content_type]}
              class="grid grid-cols-1 gap-related sm:grid-cols-3"
            >
              <:item
                :for={content_type <- @content_types}
                value={to_string(content_type)}
                class="group/radio-card grid cursor-pointer grid-cols-[auto_1fr_auto] items-center gap-related rounded-control border border-border bg-surface-inset p-group transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected [&>[data-slot=radio-group-item]]:sr-only"
              >
                <.content_type_icon type={content_type} class="size-icon text-text-muted" />
                <span class="font-medium">{ContentType.translated_label(content_type)}</span>
                <Lucideicons.check class="size-icon-sm text-primary opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
              </:item>
            </.radio_group>
          </:control>
        </.field>

        <:action>
          <.button type="button" variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button type="submit">
            {dgettext("clubs", "Create library")}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :target, :any, default: nil

  def rename_library_modal(assigns) do
    ~H"""
    <.modal id="rename-library-modal" on_close={push_to_target("close_modals", @target)}>
      <:title>{dgettext("clubs", "Rename Library")}</:title>
      <.form
        for={@form}
        id="rename-library-form"
        phx-change="validate_rename_library"
        phx-submit="submit_rename_library"
        phx-target={@target}
        phx-mounted={JS.focus_first()}
      >
        <.field field={@form[:name]} label={dgettext("clubs", "Library name")} type="text" />

        <:action>
          <.button type="button" variant="secondary" data-modal-close>
            {dgettext("default", "Cancel")}
          </.button>
          <.button type="submit">
            {dgettext("clubs", "Rename Library")}
          </.button>
        </:action>
      </.form>
    </.modal>
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

  defp push_to_target(event, nil), do: JS.push(event)
  defp push_to_target(event, target), do: JS.push(event, target: target)
end
