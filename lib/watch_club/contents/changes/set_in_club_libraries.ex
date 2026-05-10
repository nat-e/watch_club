defmodule WatchClub.Contents.Changes.SetInClubLibraries do
  use Ash.Resource.Change

  require Logger

  @impl true
  def change(changeset, _opts, context) do
    club_ids = Ash.Changeset.get_argument(changeset, :club_ids)

    Ash.Changeset.after_action(changeset, fn _changeset, movie ->
      movie.content
      |> Ash.Changeset.for_update(:set_in_club_libraries, %{club_ids: club_ids})
      |> Ash.update(actor: context.actor)
      |> case do
        {:ok, _content} -> {:ok, movie}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
