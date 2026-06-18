defmodule WatchClubWeb.HomePage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Home.ContinueWatchingSection

  alias WatchClub.Contents.ContentView

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}>
      <.continue_watching_section
        :if={@continue_watching != []}
        contents={@continue_watching}
        current_user={@current_user}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> load_continue_watching()}
  end

  defp load_continue_watching(socket) do
    contents =
      Contents.get_user_recently_watched!(actor: socket.assigns.current_user)
      |> Enum.map(&ContentView.from_content(&1))

    socket |> assign(:continue_watching, contents)
  end
end
