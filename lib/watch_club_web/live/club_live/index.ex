defmodule WatchClubWeb.ClubLive.Index do
  alias WatchClub.Clubs
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- <.header>
        Listing Clubs
        <:actions>
          <.button navigate={~p"/clubs/new"}>
            <Lucideicons.plus /> New Club
          </.button>
        </:actions>
      </.header> --%>

      <%!-- <.table>
        <.table_header>
          <.table_row>
            <.table_head>Name</.table_head>
            <.table_head class="w-0">
              <span class="sr-only">{gettext("Actions")}</span>
            </.table_head>
          </.table_row>
        </.table_header>
        <.table_body id="clubs" phx-update="stream">
          <.table_row :for={{id, club} <- @streams.clubs} id={id} class="cursor-pointer">
            <.table_cell phx-click={JS.navigate(~p"/clubs/#{club}")}>{club.name}</.table_cell>
            <.table_cell class="font-semibold">
              <div class="flex gap-4">
                <.link navigate={~p"/clubs/#{club}/edit"}>Edit</.link>
                <.link
                  phx-click={JS.push("delete", value: %{id: club.id}) |> hide("##{id}")}
                  data-confirm="Are you sure?"
                >
                  Delete
                </.link>
              </div>
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table> --%>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Clubs")
     |> stream(
       :clubs,
       Clubs.list_clubs!(authorize?: false)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    club = Clubs.get_club_by_id!(id)
    Clubs.destroy_club!(club)

    {:noreply, stream_delete(socket, :clubs, club)}
  end
end
