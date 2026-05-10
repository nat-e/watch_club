defmodule WatchClub.Contents.Changes.CreateOrUpdateMovie do
  use Ash.Resource.Change

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Contents.{Content, MovieLocalization}
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    tmdb_id = Ash.Changeset.get_argument_or_attribute(changeset, :tmdb_id)

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Setting movie from TMDB: #{tmdb_id}")

      case WatchClub.Integrations.Tmdb.get_movie_details(tmdb_id) do
        {:ok, %MovieDetailsResponse{} = movie} ->
          Logger.info("Movie fetched: #{tmdb_id}")

          changeset
          |> set_base_content(movie)
          |> set_localizations(movie)

        {:error, error} ->
          Logger.warning("Error fetching movie: #{inspect(error)}")

          changeset
          |> Ash.Changeset.add_error(
            message: "Failed to fetch movie from TMDB",
            private_vars: [tmdb_error: error.reason]
          )
      end
    end)
  end

  defp set_base_content(%Ash.Changeset{} = changeset, %MovieDetailsResponse{} = movie) do
    production_country = movie.production_countries |> List.first() |> Map.get(:iso_3166_1)

    Ash.Changeset.manage_relationship(
      changeset,
      :content,
      %Content{
        type: :movie,
        external_id_source: :tmdb,
        external_id: Integer.to_string(movie.id),
        original_title: movie.original_title,
        original_language: movie.original_language,
        origin_country: production_country,
        release_date: movie.release_date
      },
      type: :direct_control
    )
  end

  defp set_localizations(%Ash.Changeset{} = changeset, %MovieDetailsResponse{} = movie) do
    localizations =
      UserLocale.values() |> Enum.map(fn locale -> build_localizations(movie, locale) end)

    Logger.info("Adding #{length(localizations)} to changeset")

    Ash.Changeset.manage_relationship(changeset, :localizations, localizations,
      type: :direct_control,
      bulk?: true
    )
  end

  defp build_localizations(%MovieDetailsResponse{} = movie, locale) do
    [iso_639_1, iso_3166_1] = locale |> Atom.to_string() |> String.split("_")

    translation =
      movie.translations
      |> Enum.find(fn t -> t.iso_639_1 == iso_639_1 and t.iso_3166_1 == iso_3166_1 end)

    best_poster =
      movie.images.posters
      |> Enum.find(fn p -> p.iso_639_1 == iso_639_1 end)

    %MovieLocalization{
      iso_639_1: iso_639_1,
      iso_3166_1: iso_3166_1,
      title: (translation && translation.data.title) || movie.title,
      overview: (translation && translation.data.overview) || movie.overview,
      poster_path: (best_poster && best_poster.file_path) || movie.poster_path,
      runtime: (translation && translation.data.runtime) || movie.runtime
    }
  end
end
