defmodule WatchClub.Playbacks.Session.Changes.PickTracks do
  @moduledoc """
  Switches the Playback given as the `playback_id` argument to the `audio_track_id` and
  `text_track_id` arguments.
  """
  use Ash.Resource.Change

  alias WatchClub.Playbacks.Playback

  @impl true
  def change(changeset, _opts, context) do
    %{playback_id: playback_id} = arguments = changeset.arguments

    Ash.Changeset.after_action(changeset, fn _changeset, session ->
      Playback
      |> Ash.get!(playback_id, scope: context)
      |> Ash.update!(Map.take(arguments, [:audio_track_id, :text_track_id]),
        action: :pick_tracks,
        scope: context
      )

      {:ok, session}
    end)
  end
end
