defmodule WatchClub.Playbacks.Session.Changes.StartPlayback do
  @moduledoc """
  Starts a new Playback on this Session for the Media identified by the
  action's `:media_id` argument. Assumes any previously current Playback has
  already been ended earlier in the action.
  """
  use Ash.Resource.Change

  alias WatchClub.Playbacks.Playback

  @impl true
  def change(changeset, _opts, context) do
    media_id = Ash.Changeset.get_argument(changeset, :media_id)

    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      Playback
      |> Ash.Changeset.for_create(:create, %{session_id: session.id, media_id: media_id},
        scope: context
      )
      |> Ash.create!()

      {:ok, session}
    end)
  end
end
