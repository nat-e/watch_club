defmodule WatchClubWeb.Helpers.Parts do
  @moduledoc "Names Parts for display, in the User's locale."
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.MediaCatalog.Part

  @doc "A Part's display name: its name from its source, such as Main Card, else Part 2."
  def name(%Part{name: nil, number: number}),
    do: dgettext("contents", "Part %{number}", number: number)

  def name(%Part{name: name}), do: name
end
