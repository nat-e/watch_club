defmodule WatchClub.MediaCatalog.Changes.RelateParts do
  @moduledoc """
  Makes the Video hold exactly the Parts of its `parts` argument, finding or creating each one.
  A Part is a `movie_id`, `tv_show_episode_id` or `sports_event_id`, a `number` and an optional
  `name`. Copies of a Part share it.

  Sets the `parts_changed?` context when the Video's Parts aren't the ones it held.
  """
  use Ash.Resource.Change

  alias WatchClub.MediaCatalog.Part

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      parts =
        changeset
        |> Ash.Changeset.get_argument(:parts)
        |> Enum.map(&Ash.create!(Part, &1, action: :upsert, scope: context))

      held =
        if changeset.action_type == :create,
          do: [],
          else: Ash.load!(changeset.data, :parts, authorize?: false).parts

      changeset
      |> Ash.Changeset.put_context(
        :parts_changed?,
        MapSet.new(parts, & &1.id) != MapSet.new(held, & &1.id)
      )
      |> Ash.Changeset.manage_relationship(:parts, parts,
        type: :append_and_remove,
        authorize?: false
      )
    end)
  end
end
