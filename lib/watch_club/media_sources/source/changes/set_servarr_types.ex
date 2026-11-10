defmodule WatchClub.MediaSources.Source.Changes.SetServarrTypes do
  @moduledoc """
  Derives `:source_type` and `:media_type` from the `:flavor` argument on
  `Source`'s `:create_servarr` action. The `source_type` mirrors the
  flavor; the `media_type` is the content kind that flavor's app imports.
  """
  use Ash.Resource.Change

  alias WatchClub.MediaSources.Servarr.Flavor

  @impl true
  def change(changeset, _opts, _context) do
    flavor = Ash.Changeset.get_argument(changeset, :flavor)

    if flavor in Flavor.values() do
      changeset
      |> Ash.Changeset.force_change_attribute(:source_type, flavor)
      |> Ash.Changeset.force_change_attribute(:media_type, Flavor.app(flavor).media_type())
    else
      Ash.Changeset.add_error(changeset,
        field: :flavor,
        message: "unknown flavor: #{inspect(flavor)}"
      )
    end
  end
end
