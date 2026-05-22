defmodule WatchClub.Contents.Preparations.SortLocalizationsByRank do
  use Ash.Resource.Preparation

  alias WatchClub.Accounts.UserLocale

  @impl true
  def prepare(query, _opts, %{actor: %{settings: %{locale: locale}}}) do
    [preferred_iso_639_1, preferred_iso_3166_1] = UserLocale.split(locale)

    Ash.Query.default_sort(query,
      rank:
        {%{
           preferred_iso_639_1: preferred_iso_639_1,
           preferred_iso_3166_1: preferred_iso_3166_1
         }, :asc},
      iso_639_1: :asc,
      iso_3166_1: :asc
    )
  end

  def prepare(query, _opts, _context) do
    Ash.Query.default_sort(query, iso_639_1: :asc, iso_3166_1: :asc)
  end
end
