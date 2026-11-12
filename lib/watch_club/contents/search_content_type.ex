defmodule WatchClub.Contents.SearchContentType do
  use Gettext, backend: WatchClubWeb.Gettext

  use Ash.Type.Enum,
    values: [
      movies_and_shows: [label: "Movies and Shows"],
      sports_events: [label: "Sports"]
    ]

  def translated_label(:movies_and_shows), do: dgettext("content_types", "Movies and TV shows")
  def translated_label(:sports_events), do: dgettext("content_types", "Sports")

  @doc "The Content Types in this scope."
  def content_types(:movies_and_shows), do: [:movie, :tv_show]
  def content_types(:sports_events), do: [:sports_event]
end
