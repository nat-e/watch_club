defmodule WatchClubWeb.Components.Clubs do
  use WatchClubWeb, :component

  attr :club, Club, required: true

  def club_avatar(assigns) do
    assigns =
      assigns
      |> assign(:avatar_bg_color, get_bg_color_class(assigns.club.id))
      |> assign(
        :initials,
        assigns.club.name
        |> String.split(~r/\s+/, trim: true)
        |> Enum.take(2)
        |> Enum.map_join("", &String.upcase(String.first(&1)))
      )

    ~H"""
    <.avatar>
      <:fallback class={["text-white", @avatar_bg_color]}>{@initials}</:fallback>
    </.avatar>
    """
  end
end
