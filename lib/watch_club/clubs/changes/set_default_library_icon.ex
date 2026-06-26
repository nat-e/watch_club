defmodule WatchClub.Clubs.Changes.SetDefaultLibraryIcon do
  @moduledoc """
  Sets a default library icon based on the content type.
  """
  use Ash.Resource.Change

  @default_by_content_type %{
    movie: "film",
    tv_show: "tv",
    book: "book_open"
  }

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :content_type) do
      nil ->
        changeset

      content_type ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :icon,
          Map.fetch!(@default_by_content_type, content_type)
        )
    end
  end
end
