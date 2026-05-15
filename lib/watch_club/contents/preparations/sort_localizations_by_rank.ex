defmodule WatchClub.Contents.Preparations.SortLocalizationsByRank do
  use Ash.Resource.Preparation

  alias WatchClub.Accounts.UserLocale

  @impl true
  def prepare(query, _opts, %{actor: %{settings: %{locale: locale}}}) do
    [preferred_iso_639_1, preferred_iso_3166_1] = UserLocale.split(locale)

    query
    |> Ash.Query.default_sort(
      rank:
        {%{
           preferred_iso_639_1: preferred_iso_639_1,
           preferred_iso_3166_1: preferred_iso_3166_1
         }, :asc},
      iso_639_1: :asc,
      iso_3166_1: :asc
    )
  end
end
