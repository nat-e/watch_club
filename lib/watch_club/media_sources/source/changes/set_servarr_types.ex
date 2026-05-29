defmodule WatchClub.MediaSources.Source.Changes.SetServarrTypes do
  @moduledoc """
  Derives `:source_type` and `:media_type` from the `:flavor` argument on
  `Source`'s `:create_servarr` action. The `source_type` mirrors the
  flavor (`:radarr` / `:sonarr`); the `media_type` is the content kind that
  flavor imports (Radarr → movies, Sonarr → TV show episodes).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :flavor) do
      :radarr ->
        changeset
        |> Ash.Changeset.force_change_attribute(:source_type, :radarr)
        |> Ash.Changeset.force_change_attribute(:media_type, :movie)

      :sonarr ->
        changeset
        |> Ash.Changeset.force_change_attribute(:source_type, :sonarr)
        |> Ash.Changeset.force_change_attribute(:media_type, :tv_show_episode)

      other ->
        Ash.Changeset.add_error(changeset,
          field: :flavor,
          message: "unknown flavor: #{inspect(other)}"
        )
    end
  end
end
