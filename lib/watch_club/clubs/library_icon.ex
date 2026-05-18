defmodule WatchClub.Clubs.LibraryIcon do
  @default_by_content_type %{
    movie: "film",
    tv_show: "tv",
    book: "book_open"
  }

  @names Lucideicons.icon_names() |> Enum.map(&Atom.to_string/1)

  def names, do: @names

  def valid?(icon_name) when is_binary(icon_name), do: icon_name in @names
  def valid?(_icon_name), do: false

  def default_for_content_type(content_type),
    do: Map.fetch!(@default_by_content_type, content_type)
end
