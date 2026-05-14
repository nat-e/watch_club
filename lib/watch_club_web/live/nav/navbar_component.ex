defmodule WatchClubWeb.Live.Nav.NavbarComponent do
  use WatchClubWeb, :live_component

  import WatchClubWeb.Live.Nav.Components.Search

  alias WatchClubWeb.Live.Nav.SidebarComponent

  @max_search_results 5

  @impl true
  def render(assigns) do
    ~H"""
    <header class="z-10 flex h-row-lg items-center justify-between gap-related border-b px-related sm:gap-group sm:px-group">
      <div class="flex w-full items-center gap-related">
        <.button
          variant="ghost"
          size="icon-sm"
          class="block md:hidden"
          aria-label={dgettext("nav", "Open navigation")}
          aria-controls="sidebar-panel"
          phx-click={SidebarComponent.show_sidebar()}
        >
          <Lucideicons.menu class="size-icon-lg font-bold" />
        </.button>
        <div class="w-full">
          <.desktop_search {assigns} />
          <.mobile_search {assigns} />
        </div>
      </div>
      <.dropdown_menu>
        <:trigger>
          <.button
            size="icon-sm"
            variant="ghost"
            class="rounded-full p-0"
            aria-label={dgettext("nav", "User menu")}
          >
            <.avatar id={@current_user.id} name={@current_user.username} />
          </.button>
        </:trigger>
        <.dropdown_menu_item href={~p"/settings"}>
          <Lucideicons.settings /> {dgettext("nav", "Settings")}
        </.dropdown_menu_item>
        <.dropdown_menu_item href={~p"/sign-out"} method="delete" variant="destructive">
          <Lucideicons.log_out /> {dgettext("nav", "Sign out")}
        </.dropdown_menu_item>
      </.dropdown_menu>
    </header>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket |> assign(:search_results, nil)}
  end

  @impl true
  def update(assigns, socket) do
    form =
      Contents.form_to_search_content(
        params: %{location: "", content_type: :movies_and_shows},
        actor: assigns.current_user
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:search_results, nil)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("preview_search", %{"form" => params}, socket) do
    # Validate is used to update the form values after an input changes.
    # This is necessary after calling change in JS for our location/content-type buttons to update on mobile
    # Errors are handled manually
    form = AshPhoenix.Form.validate(socket.assigns.form, params, errors: false)
    socket = assign(socket, :form, form)

    if params["query"] == "" do
      {:noreply,
       socket
       |> cancel_async(:preview_search, :cancel)
       |> assign(:search_results, nil)}
    else
      {:noreply,
       start_async(socket, :preview_search, fn ->
         AshPhoenix.Form.submit!(form, params: params)
       end)}
    end
  end

  def handle_event("open_search", %{"form" => %{"query" => ""}}, socket) do
    {:noreply, socket}
  end

  def handle_event("open_search", %{"form" => params}, socket) do
    search_url =
      case params do
        %{"location" => "", "content_type" => type, "query" => query} ->
          ~p"/search?type=#{type}&query=#{query}"

        %{"location" => club_id, "content_type" => type, "query" => query} ->
          ~p"/search?type=#{type}&club_id=#{club_id}&query=#{query}"
      end

    {:noreply, socket |> redirect(to: search_url)}
  end

  @impl true
  def handle_async(:preview_search, {:ok, results}, socket) do
    {:noreply, socket |> assign(:search_results, Enum.take(results, @max_search_results))}
  end

  def handle_async(:preview_search, {:exit, %Phoenix.HTML.Form{} = form}, socket) do
    {:noreply, socket |> assign(:form, form) |> assign(:search_results, nil)}
  end

  def handle_async(:preview_search, {:exit, _reason}, socket) do
    {:noreply, socket}
  end
end
