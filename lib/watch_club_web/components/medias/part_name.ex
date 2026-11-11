defmodule WatchClubWeb.Components.Medias.PartName do
  @moduledoc "The name of a Part: the one its source gives it, such as Main Card, else Part 2."
  use WatchClubWeb, :component

  alias WatchClub.MediaCatalog.Part

  attr :part, Part, required: true

  def part_name(%{part: %Part{name: nil}} = assigns) do
    ~H"""
    {dgettext("contents", "Part %{number}", number: @part.number)}
    """
  end

  def part_name(assigns) do
    ~H"""
    {@part.name}
    """
  end
end
