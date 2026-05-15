defmodule WatchClub.Contents.Calculations.LocalizationRank do
  use Ash.Resource.Calculation

  @impl true
  def expression(_opts, context) do
    arguments = Map.fetch!(context, :arguments)
    preferred_iso_639_1 = Map.fetch!(arguments, :preferred_iso_639_1)
    preferred_iso_3166_1 = Map.fetch!(arguments, :preferred_iso_3166_1)

    expr(
      cond do
        iso_639_1 == ^preferred_iso_639_1 and iso_3166_1 == ^preferred_iso_3166_1 ->
          type(0, :integer)

        iso_639_1 == ^preferred_iso_639_1 ->
          type(1, :integer)

        iso_639_1 == "en" ->
          type(2, :integer)

        true ->
          type(3, :integer)
      end
    )
  end
end
