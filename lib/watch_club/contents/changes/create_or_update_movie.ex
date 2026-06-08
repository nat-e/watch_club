defmodule WatchClub.Contents.Changes.CreateOrUpdateMovie do
  use Ash.Resource.Change

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    tmdb_id =
      String.to_integer(
        Ash.Changeset.get_attribute(changeset, :external_id) ||
          Ash.Changeset.get_argument(changeset, :content_identity).external_id
      )

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Setting movie from TMDB: #{tmdb_id}")

      case WatchClub.Integrations.Tmdb.get_movie_details(tmdb_id) do
        {:ok, %MovieDetailsResponse{} = movie} ->
          Logger.info("Movie fetched: #{tmdb_id}")

          changeset
          |> set_base_content(movie)
          |> set_movie(movie)

        {:error, error} ->
          Logger.warning("Error fetching movie: #{inspect(error)}")

          changeset
          |> Ash.Changeset.add_error(
            message: "Failed to fetch movie from TMDB",
            private_vars: [tmdb_error: error]
          )
      end
    end)
  end

  defp set_movie(%Ash.Changeset{} = changeset, %MovieDetailsResponse{} = movie) do
    localizations =
      UserLocale.values() |> Enum.map(fn locale -> build_localizations(movie, locale) end)

    Logger.info("Adding #{length(localizations)} to changeset")

    changeset
    |> Ash.Changeset.manage_relationship(:movie, %{localizations: localizations},
      type: :direct_control,
      authorize?: false
    )
  end

  defp set_base_content(%Ash.Changeset{} = changeset, %MovieDetailsResponse{} = movie) do
    production_country =
      case movie.production_countries do
        [%{iso_3166_1: iso_3166_1} | _] -> iso_3166_1
        _ -> List.first(movie.origin_country)
      end

    changeset
    |> Ash.Changeset.force_change_attribute(:type, :movie)
    |> Ash.Changeset.force_change_attribute(:external_id_source, :tmdb)
    |> Ash.Changeset.force_change_attribute(:external_id, Integer.to_string(movie.id))
    |> Ash.Changeset.force_change_attribute(:original_title, movie.original_title)
    |> Ash.Changeset.force_change_attribute(:original_language, movie.original_language)
    |> Ash.Changeset.force_change_attribute(:origin_country, production_country)
    |> Ash.Changeset.force_change_attribute(:release_date, movie.release_date)
  end

  defp build_localizations(%MovieDetailsResponse{} = movie, locale) do
    [iso_639_1, iso_3166_1] = locale |> Atom.to_string() |> String.split("_")

    translation =
      movie.translations
      |> Enum.find(fn t -> t.iso_639_1 == iso_639_1 and t.iso_3166_1 == iso_3166_1 end)

    translation_data = if translation, do: translation.data

    best_poster =
      ((movie.images && movie.images.posters) || [])
      |> Enum.find(fn p -> p.iso_639_1 == iso_639_1 end)

    %{
      iso_639_1: iso_639_1,
      iso_3166_1: iso_3166_1,
      title: translated_or_default(translation_data, :title, movie.title),
      overview: translated_or_default(translation_data, :overview, movie.overview),
      poster_path: translated_or_default(best_poster, :file_path, movie.poster_path),
      runtime: translated_or_default(translation_data, :runtime, movie.runtime)
    }
  end

  defp translated_or_default(nil, _key, default), do: default

  defp translated_or_default(translation, key, default) do
    # TMDB tends to return empty strings or 0 for missing values
    case Map.get(translation, key) do
      nil -> default
      "" -> default
      0 -> default
      value -> value
    end
  end
end
