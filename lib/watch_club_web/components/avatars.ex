defmodule WatchClubWeb.Components.Avatars do
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :rest, :global, include: ~w(class size)

  def generic_avatar(assigns) do
    assigns =
      assigns
      |> assign(:avatar_bg_color, get_bg_color_class(assigns.id))
      |> assign(
        :initials,
        assigns.name
        |> String.split(~r/[\s_]+/, trim: true)
        |> Enum.take(2)
        |> Enum.map_join("", &String.upcase(String.first(&1)))
      )

    ~H"""
    <.avatar {@rest}>
      <:fallback class={["text-white", @avatar_bg_color]}>{@initials}</:fallback>
    </.avatar>
    """
  end
end
