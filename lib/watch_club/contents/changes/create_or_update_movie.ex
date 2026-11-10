defmodule WatchClub.Contents.Changes.CreateOrUpdateMovie do
  use Ash.Resource.Change

  alias WatchClub.Accounts.UserLocale

  alias WatchClub.Contents.{
    CastMember,
    Genre,
    MetadataUnavailable,
    Movie,
    MovieLocalization,
    Rating
  }

  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.MovieDetailsResponse
  alias WatchClub.Integrations.Tmdb.Types.{Images, Videos}

  require Logger

  @impl true
  def change(changeset, _opts, context) do
    tmdb_id =
      String.to_integer(
        Ash.Changeset.get_attribute(changeset, :external_id) ||
          Ash.Changeset.get_argument(changeset, :content_identity).external_id
      )

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Refreshing Movie metadata for TMDB ID: #{tmdb_id}",
        event: :refreshing_movie_metadata,
        tmdb_id: tmdb_id
      )

      case fetch_details_by_locale(tmdb_id) do
        {:ok, details_by_locale} ->
          # Each Locale's response has every translation and image; the default one is the base
          movie = Map.fetch!(details_by_locale, UserLocale.default())

          localizations =
            Enum.map(details_by_locale, fn {locale, details} ->
              build_localization(movie, locale, details)
            end)

          changeset
          |> set_base_content(movie)
          |> Ash.Changeset.force_change_attribute(:metadata_refreshed_at, DateTime.utc_now())
          |> Ash.Changeset.after_action(fn _changeset, content ->
            Ash.bulk_create!(
              [%{id: content.id, backdrop_path: Images.best_backdrop_path(movie.images)}],
              Movie,
              :create,
              scope: context
            )

            localizations
            |> Enum.map(&Map.put(&1, :movie_id, content.id))
            |> Ash.bulk_create!(MovieLocalization, :create, scope: context)

            {:ok, content}
          end)

        {:error, reason} ->
          Ash.Changeset.add_error(changeset, MetadataUnavailable.exception(reason: reason))
      end
    end)
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
    |> Ash.Changeset.force_change_attribute(:genres, Genre.from_tmdb(movie.genres))
    |> Ash.Changeset.force_change_attribute(:rating, Rating.from_tmdb(movie))
  end

  # One response per Locale, for its cast and trailer
  defp fetch_details_by_locale(tmdb_id) do
    Enum.reduce_while(UserLocale.values(), {:ok, %{}}, fn locale, {:ok, details_by_locale} ->
      case Tmdb.get_movie_details(tmdb_id, locale: locale, cache: false) do
        {:ok, details} -> {:cont, {:ok, Map.put(details_by_locale, locale, details)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_localization(%MovieDetailsResponse{} = movie, locale, localized_details) do
    [iso_639_1, iso_3166_1] = UserLocale.split(locale)

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
      runtime: translated_or_default(translation_data, :runtime, movie.runtime),
      cast: CastMember.from_tmdb(localized_details.credits),
      trailer_url: Videos.youtube_trailer_url(localized_details.videos)
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
