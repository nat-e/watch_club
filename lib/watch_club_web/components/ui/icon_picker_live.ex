defmodule WatchClubWeb.Components.UI.IconPickerLive do
  @moduledoc """
  Shared stateful icon picker modal backed by a paged LiveView stream.
  """
  use WatchClubWeb, :live_component

  @icon_names Lucideicons.icon_names() |> Enum.map(&Atom.to_string/1)
  @page_size 96

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream_configure(:icons, dom_id: & &1.id)
     |> assign(
       form: icon_search_form(""),
       icon_page: 1,
       icons_end?: false,
       query: "",
       results_empty?: false
     )
     |> reset_icons("")}
  end

  attr :description, :any, required: true
  attr :on_close, :any, required: true
  attr :on_select, :any, required: true
  attr :selected_icon, :string, required: true
  attr :title, :string, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-root"} class="contents">
      <.modal
        id={"#{@id}-modal"}
        size="lg"
        on_close={@on_close}
      >
        <:title>{@title}</:title>
        <:description>{@description}</:description>

        <.form
          for={@form}
          id={"#{@id}-search-form"}
          layout="none"
          phx-change="search_icons"
          phx-target={@myself}
        >
          <.input
            id={"#{@id}-search-input"}
            field={@form[:query]}
            placeholder={dgettext("clubs", "Search icons")}
            phx-debounce="200"
            autocomplete="off"
          />
        </.form>

        <div class="max-h-[min(28rem,60dvh)] overflow-y-auto rounded-control border border-border bg-surface-inset p-related">
          <.empty
            :if={@results_empty?}
            id={"#{@id}-empty"}
            size="sm"
            border={false}
            class="min-h-48"
          >
            <:icon><Lucideicons.search_x /></:icon>
            <:title>{dgettext("clubs", "No icons found")}</:title>
            <:description>{dgettext("clubs", "Try a different search term.")}</:description>
          </.empty>

          <div
            :if={!@results_empty?}
            id={"#{@id}-results"}
            phx-update="stream"
            phx-viewport-bottom={!@icons_end? && JS.push("load_more_icons", target: @myself)}
            class="grid grid-cols-4 gap-tight sm:grid-cols-6 md:grid-cols-8"
          >
            <.button
              :for={{dom_id, icon} <- @streams.icons}
              id={dom_id}
              variant="ghost"
              size="icon"
              phx-click={@on_select}
              phx-value-icon={icon.name}
              aria-label={dgettext("clubs", "Use %{icon_name} icon", icon_name: icon.name)}
              title={icon.name}
            >
              <.lucide_icon name={icon.name} class="size-icon-lg" />
            </.button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("search_icons", %{"icon_search" => %{"query" => query}}, socket) do
    {:noreply, reset_icons(socket, query)}
  end

  def handle_event("load_more_icons", _params, %{assigns: %{icons_end?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("load_more_icons", _params, socket) do
    {:noreply, load_icon_page(socket, socket.assigns.icon_page + 1)}
  end

  defp reset_icons(socket, query) do
    icons = matching_icons(query)
    page_icons = Enum.take(icons, @page_size)

    socket
    |> assign(
      form: icon_search_form(query),
      icon_page: 1,
      icons_end?: length(icons) <= @page_size,
      query: query,
      results_empty?: icons == []
    )
    |> stream(:icons, icon_items(page_icons), reset: true)
  end

  defp load_icon_page(socket, page) do
    icons = matching_icons(socket.assigns.query)

    page_icons =
      icons
      |> Enum.drop((page - 1) * @page_size)
      |> Enum.take(@page_size)

    if page_icons == [] do
      assign(socket, :icons_end?, true)
    else
      socket
      |> assign(
        icon_page: page,
        icons_end?: page * @page_size >= length(icons)
      )
      |> stream(:icons, icon_items(page_icons), at: -1)
    end
  end

  defp matching_icons(query) do
    query = query |> to_string() |> String.downcase() |> String.trim()

    Enum.filter(@icon_names, &String.contains?(&1, query))
  end

  defp icon_items(icon_names) do
    Enum.map(icon_names, fn icon_name ->
      %{id: "icon-picker-option-#{icon_name}", name: icon_name}
    end)
  end

  defp icon_search_form(query) do
    to_form(%{"query" => query || ""}, as: :icon_search)
  end
end
