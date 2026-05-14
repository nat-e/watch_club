defmodule WatchClubWeb.ClubsLive.LibraryShow do
  use WatchClubWeb, :live_view

  require Logger

  alias WatchClub.Contents.ContentView

  @impl true
  def render(%{library: %Library{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      class="!p-2"
      space="none"
    >
      <.stack space="group" class="w-full">
        <header class="flex w-full items-center">
          <h1 class="w-full truncate text-2xl font-bold">{@library.name}</h1>
        </header>

        <.empty :if={@contents == []}>
          <:icon><Lucideicons.library /></:icon>
          <:title>{dgettext("clubs", "Library is empty")}</:title>
          <:description>
            {dgettext("clubs", "This library does not have any content yet.")}
          </:description>
        </.empty>

        <div
          :if={@contents != []}
          class="grid grid-cols-[repeat(auto-fill,minmax(10rem,1fr))] gap-group"
        >
          <.content_card
            :for={content <- @contents}
            content={content}
            library_id_context={@library.id}
          />
        </div>
      </.stack>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}></Layouts.app>
    """
  end

  @impl true
  def mount(%{"library_id" => library_id}, _session, socket) do
    case Clubs.view_library(library_id, actor: socket.assigns.current_user) do
      {:ok, library} ->
        locale = socket.assigns.current_user.settings.locale

        contents =
          Enum.map(library.items, fn item -> ContentView.from_content(item.content, locale) end)

        {:ok,
         socket
         |> assign(:library, library)
         |> assign(:contents, contents)}

      {:error, error} ->
        Logger.warning("Error loading library: #{inspect(error)}")

        {:ok,
         socket
         |> put_flash(:error, dgettext("clubs", "Could not load library"))
         |> redirect(to: ~p"/")}
    end
  end
end
