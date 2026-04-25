defmodule WatchClubWeb.ClubLive.Show do
  alias WatchClub.Clubs
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Club {@club.id}
        <:subtitle>This is a club record from your database.</:subtitle>

        <:actions>
          <.button navigate={~p"/clubs"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/clubs/#{@club}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit Club
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@club.id}</:item>

        <:item title="Name">{@club.name}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Club")
     |> assign(:club, Clubs.get_club_by_id!(id))}
  end
end
