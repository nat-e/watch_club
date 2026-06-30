defmodule WatchClub.Contents.Changes.CreateOrUpdateTvShow do
  use Ash.Resource.Change

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    tmdb_id =
      String.to_integer(
        Ash.Changeset.get_attribute(changeset, :external_id) ||
          Ash.Changeset.get_argument(changeset, :content_identity).external_id
      )

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Creating TV show for TMDB ID: #{tmdb_id}",
        event: :creating_tv_show,
        tmdb_id: tmdb_id
      )

      show = Tmdb.get_tv_details!(tmdb_id)

      changeset
      |> set_base_content(show)
      |> set_tv_show(show)
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
  end

  defp set_tv_show(%Ash.Changeset{} = changeset, %TvDetailsResponse{} = tv_show) do
    Ash.Changeset.manage_relationship(
      changeset,
      :tv_show,
      %{
        original_name: tv_show.original_name,
        tmdb_id: tv_show.id,
        tvdb_id: tv_show.external_ids.tvdb_id,
        localizations: build_localizations(tv_show),
        episodes: build_episodes(tv_show)
      },
      type: :direct_control,
      authorize?: false
    )
  end

  defp build_localizations(%TvDetailsResponse{} = tv_show) do
    Enum.map(UserLocale.values(), fn locale ->
      [iso_639_1, iso_3166_1] = locale |> Atom.to_string() |> String.split("_")

      translation =
        Enum.find(tv_show.translations, fn t ->
          t.iso_639_1 == iso_639_1 and t.iso_3166_1 == iso_3166_1
        end)

      translation_data = translation && translation.data

      best_poster =
        ((tv_show.images && tv_show.images.posters) || [])
        |> Enum.find(fn p -> p.iso_639_1 == iso_639_1 end)

      %{
        iso_639_1: iso_639_1,
        iso_3166_1: iso_3166_1,
        title: translated_or_default(translation_data, :name, tv_show.name),
        overview: translated_or_default(translation_data, :overview, tv_show.overview),
        poster_path: translated_or_default(best_poster, :file_path, tv_show.poster_path)
      }
    end)
  end

  defp build_episodes(%TvDetailsResponse{id: tmdb_id} = tv_show) do
    seasons = Enum.filter(tv_show.seasons, &(&1.season_number >= 1 and &1.episode_count >= 1))
    episode_details = fetch_episode_details(tmdb_id, seasons)

    Enum.flat_map(seasons, fn season ->
      season_episode_details = Map.get(episode_details, season.season_number, %{})

      Enum.map(1..season.episode_count, fn episode_number ->
        episode_details = Map.get(season_episode_details, episode_number)

        %{
          season_number: season.season_number,
          episode_number: episode_number,
          air_date: (episode_details && episode_details.air_date) || nil,
          still_path: (episode_details && episode_details.still_path) || nil
        }
      end)
    end)
  end

  # Per-episode detail only come from the season-details endpoint (the base
  # TV details payload carries season counts, not episode air dates or still images),
  # so we fetch one season at a time — concurrently, since a long-running show has many
  # seasons and this runs inline before the Content is created.
  # Crashes the process when one call fails, so that the entire action fails.
  # We do not take care of max concurrency here, this is handled by the Tmdb client.
  @spec fetch_episode_details(integer(), [integer()]) :: %{
          integer() => %{integer() => WatchClub.Integrations.Tmdb.TvDetailsResponse.SeasonDetails}
        }
  defp fetch_episode_details(tmdb_id, seasons) do
    seasons
    |> Task.async_stream(
      fn season ->
        {season.season_number,
         Tmdb.get_tv_season_details!(tmdb_id, season.season_number).episodes
         |> Map.new(&{&1.episode_number, &1})}
      end,
      ordered: false,
      timeout: 10_000
    )
    |> Enum.reduce(%{}, fn
      {:ok, {season_number, details}}, acc -> Map.put(acc, season_number, details)
      {:exit, _reason}, acc -> acc
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
