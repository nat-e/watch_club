defmodule WatchClubWeb.Components.Navigation.NavbarLive do
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Navigation.Navbar.DesktopSearch
  import WatchClubWeb.Components.Navigation.Navbar.MobileSearch

  alias WatchClub.Contents.SearchResultsPage
  alias WatchClubWeb.Components.Navigation.SidebarLive

  @max_search_results 5

  @impl true
  def render(assigns) do
    ~H"""
    <header class="z-10 flex h-row-lg items-center gap-related border-b px-related sm:gap-group sm:px-group">
      <.button
        id="navbar-open-sidebar-button"
        variant="ghost"
        size="icon-sm"
        class="block md:hidden"
        aria-label={dgettext("nav", "Open navigation")}
        aria-controls="sidebar-panel"
        phx-click={SidebarLive.show_sidebar()}
      >
        <Lucideicons.menu class="size-icon-lg font-bold" />
      </.button>
      <div class="w-full">
        <.desktop_search {assigns} />
        <.mobile_search {assigns} />
      </div>
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
    {:noreply, preview_search(socket, params)}
  end

  def handle_event("retry_preview_search", _params, socket) do
    params = AshPhoenix.Form.params(socket.assigns.form, only_touched?: false)
    {:noreply, preview_search(socket, params)}
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

    {:noreply, socket |> push_navigate(to: search_url)}
  end

  defp preview_search(socket, params) do
    # Validate is used to update the form values after an input changes.
    # This is necessary after calling change in JS for our location/content-type buttons to update on mobile
    # Errors are handled manually
    form = AshPhoenix.Form.validate(socket.assigns.form, params, errors: false)
    socket = assign(socket, :form, form)

    if params["query"] in [nil, ""] do
      socket
      |> cancel_async(:preview_search, :cancel)
      |> assign(:search_results, nil)
    else
      start_async(socket, :preview_search, fn ->
        AshPhoenix.Form.submit!(form, params: params)
      end)
    end
  end

  @impl true
  def handle_async(:preview_search, {:ok, %SearchResultsPage{results: results}}, socket) do
    {:noreply, socket |> assign(:search_results, Enum.take(results, @max_search_results))}
  end

  def handle_async(:preview_search, {:exit, %Phoenix.HTML.Form{} = form}, socket) do
    {:noreply, socket |> assign(:form, form) |> assign(:search_results, nil)}
  end

  def handle_async(:preview_search, {:exit, :cancel}, socket) do
    {:noreply, socket}
  end
end
