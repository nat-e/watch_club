defmodule WatchClub.Contents.Changes.CreateOrUpdateTvShow do
  use Ash.Resource.Change

  alias OpentelemetryProcessPropagator.Task
  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Contents.{CastMember, Genre, MetadataUnavailable, Rating, TvShowEpisode}
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse
  alias WatchClub.Integrations.Tmdb.Types.{Images, Videos}

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    tmdb_id =
      String.to_integer(
        Ash.Changeset.get_attribute(changeset, :external_id) ||
          Ash.Changeset.get_argument(changeset, :content_identity).external_id
      )

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Refreshing TV Show metadata for TMDB ID: #{tmdb_id}",
        event: :refreshing_tv_show_metadata,
        tmdb_id: tmdb_id
      )

      with {:ok, details_by_locale} <- fetch_details_by_locale(tmdb_id),
           # Each Locale's response has every translation and image; the default one is the base
           show = Map.fetch!(details_by_locale, UserLocale.default()),
           {:ok, episodes} <- fetch_episodes(show) do
        localizations =
          Enum.map(details_by_locale, fn {locale, details} ->
            build_localization(show, locale, details)
          end)

        changeset
        |> set_base_content(show)
        |> Ash.Changeset.manage_relationship(
          :tv_show,
          %{
            original_name: show.original_name,
            backdrop_path: Images.best_backdrop_path(show.images),
            tmdb_id: show.id,
            tvdb_id: show.external_ids.tvdb_id,
            localizations: localizations,
            episodes: episodes
          },
          type: :direct_control,
          authorize?: false
        )
        |> Ash.Changeset.force_change_attribute(:metadata_refreshed_at, DateTime.utc_now())
      else
        {:error, reason} ->
          Ash.Changeset.add_error(changeset, MetadataUnavailable.exception(reason: reason))
      end
    end)
  end

  defp set_base_content(%Ash.Changeset{} = changeset, %TvDetailsResponse{} = tv_show) do
    changeset
    |> Ash.Changeset.force_change_attribute(:type, :tv_show)
    |> Ash.Changeset.force_change_attribute(:external_id_source, :tmdb)
    |> Ash.Changeset.force_change_attribute(:external_id, Integer.to_string(tv_show.id))
    |> Ash.Changeset.force_change_attribute(:original_title, tv_show.original_name)
    |> Ash.Changeset.force_change_attribute(:original_language, tv_show.original_language)
    |> Ash.Changeset.force_change_attribute(:origin_country, List.first(tv_show.origin_country))
    |> Ash.Changeset.force_change_attribute(:release_date, tv_show.first_air_date)
    |> Ash.Changeset.force_change_attribute(:genres, Genre.from_tmdb(tv_show.genres))
    |> Ash.Changeset.force_change_attribute(:rating, Rating.from_tmdb(tv_show))
  end

  # One response per Locale, for its cast and trailer
  defp fetch_details_by_locale(tmdb_id) do
    Enum.reduce_while(UserLocale.values(), {:ok, %{}}, fn locale, {:ok, details_by_locale} ->
      case Tmdb.get_tv_details(tmdb_id, locale: locale, cache: false) do
        {:ok, details} -> {:cont, {:ok, Map.put(details_by_locale, locale, details)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_localization(%TvDetailsResponse{} = show, locale, localized_details) do
    [iso_639_1, iso_3166_1] = UserLocale.split(locale)

    translation =
      Enum.find(show.translations, fn translation ->
        translation.iso_639_1 == iso_639_1 and translation.iso_3166_1 == iso_3166_1
      end)

    translation_data = translation && translation.data

    best_poster =
      ((show.images && show.images.posters) || [])
      |> Enum.find(&(&1.iso_639_1 == iso_639_1))

    %{
      iso_639_1: iso_639_1,
      iso_3166_1: iso_3166_1,
      title: translated_or_default(translation_data, :name, show.name),
      overview: translated_or_default(translation_data, :overview, show.overview),
      poster_path: translated_or_default(best_poster, :file_path, show.poster_path),
      cast: CastMember.from_tmdb(localized_details.credits),
      trailer_url: Videos.youtube_trailer_url(localized_details.videos)
    }
  end

  defp fetch_episodes(%TvDetailsResponse{} = show) do
    seasons = Enum.filter(show.seasons, &(&1.season_number >= 1 and &1.episode_count >= 1))

    # All seasons and Locales must succeed before any metadata is persisted.
    for(season <- seasons, locale <- UserLocale.values(), do: {season.season_number, locale})
    |> Task.async_stream(
      fn {season_number, locale} ->
        case Tmdb.get_tv_season_details(show.id, season_number, locale: locale, cache: false) do
          {:ok, details} ->
            {:ok, {{season_number, locale}, Map.new(details.episodes, &{&1.episode_number, &1})}}

          {:error, reason} ->
            {:error, reason}
        end
      end,
      max_concurrency: 4,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce_while({:ok, %{}}, fn
      {:ok, {:ok, {key, episodes}}}, {:ok, season_details} ->
        {:cont, {:ok, Map.put(season_details, key, episodes)}}

      {:ok, {:error, reason}}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, season_details} -> {:ok, build_episodes(seasons, season_details)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_episodes(seasons, season_details) do
    Enum.flat_map(seasons, fn season ->
      season_details
      |> Map.fetch!({season.season_number, UserLocale.default()})
      |> Enum.map(fn {episode_number, details} ->
        %{
          season_number: season.season_number,
          episode_number: episode_number,
          air_date: details.air_date,
          still_path: details.still_path,
          runtime: details.runtime,
          localizations:
            Enum.map(UserLocale.values(), fn locale ->
              [iso_639_1, iso_3166_1] = UserLocale.split(locale)

              translation =
                season_details
                |> Map.fetch!({season.season_number, locale})
                |> Map.get(episode_number)

              %{
                iso_639_1: iso_639_1,
                iso_3166_1: iso_3166_1,
                title:
                  translated_or_default(
                    translation,
                    :name,
                    details.name ||
                      TvShowEpisode.format_number(season.season_number, episode_number)
                  ),
                overview: translated_or_default(translation, :overview, details.overview)
              }
            end)
        }
      end)
    end)
  end

  defp translated_or_default(nil, _key, default), do: default

  defp translated_or_default(translation, key, default) do
    case Map.get(translation, key) do
      nil -> default
      "" -> default
      value -> value
    end
  end
end
