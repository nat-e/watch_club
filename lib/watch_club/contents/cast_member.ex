defmodule WatchClub.Contents.CastMember do
  @moduledoc "A person shown in a Content Localization's cast, in display order."
  use Ash.TypedStruct

  typed_struct do
    field :name, :string, allow_nil?: false
    field :role, :string
    field :profile_path, :string
  end

  @doc "The first director and up to 17 actors in billing order."
  def from_tmdb(nil), do: []

  def from_tmdb(credits) do
    directors = credits.crew |> Enum.filter(&(&1.job == "Director")) |> Enum.take(1)
    actors = credits.cast |> Enum.sort_by(&(&1.order || 999_999)) |> Enum.take(17)

    (directors ++ actors)
    |> Enum.uniq_by(&(&1.id || &1.name))
    |> Enum.map(
      &%__MODULE__{name: &1.name, role: &1.character || &1.job, profile_path: &1.profile_path}
    )
  end
end
