defmodule WatchClubWeb.Helpers.Parts do
  @moduledoc "Parts named in the User's locale."
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.MediaCatalog.Part

  @doc "The name its source gives a Part, such as Main Card, else its number: Part 2."
  def name(%Part{name: nil, number: number}),
    do: dgettext("contents", "Part %{number}", number: number)

  def name(%Part{name: name}), do: name
end
