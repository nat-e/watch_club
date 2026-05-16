defmodule WatchClub.Clubs.LibraryIcon do
  alias WatchClub.Contents.ContentType

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

  def default_for_accepted_content_types(content_types) when is_list(content_types) do
    content_type =
      Enum.find(ContentType.library_display_order(), fn content_type ->
        content_type in content_types
      end)

    default_for_content_type(content_type || :movie)
  end
end
