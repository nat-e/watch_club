defmodule WatchClub.Clubs.Changes.SetDefaultLibraryIcon do
  @moduledoc """
  Sets a default library icon based on the content type.
  """
  use Ash.Resource.Change

  alias WatchClub.Clubs.LibraryIcon

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :content_type) do
      nil ->
        changeset

      content_type ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :icon,
          LibraryIcon.default_for_content_type(content_type)
        )
    end
  end
end
