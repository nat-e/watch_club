defmodule WatchClub.Clubs.Changes.SetDefaultLibraryIcon do
  @moduledoc """
  Sets a default library icon based on the accepted content types.
  """
  use Ash.Resource.Change

  alias WatchClub.Clubs.LibraryIcon

  @impl true
  def change(changeset, _opts, _context) do
    accepted_content_types = Ash.Changeset.get_attribute(changeset, :accepted_content_types) || []

    Ash.Changeset.force_change_attribute(
      changeset,
      :icon,
      LibraryIcon.default_for_accepted_content_types(accepted_content_types)
    )
  end
end
