defmodule WatchClub.Contents.Changes.CreateOrUpdateTvShow do
  use Ash.Resource.Change

  alias WatchClub.Accounts.UserLocale
  alias WatchClub.Integrations.Tmdb
  alias WatchClub.Integrations.Tmdb.TvDetailsResponse

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    tmdb_id = Ash.Changeset.get_argument(changeset, :tmdb_id)

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Fetching TV show from TMDB: #{tmdb_id}")

      case Tmdb.get_tv_details(tmdb_id) do
        {:ok, %TvDetailsResponse{} = tv_show} ->
          Logger.info("TV show fetched: #{tmdb_id}")

          changeset
          |> set_base_content(tv_show)
          |> set_tv_show(tv_show)

        {:error, error} ->
          Logger.warning("Error fetching TV show: #{inspect(error)}")

          Ash.Changeset.add_error(changeset,
            message: "Failed to fetch TV show from TMDB",
            private_vars: [tmdb_error: error]
          )
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

  defp build_episodes(%TvDetailsResponse{} = tv_show) do
    Enum.flat_map(tv_show.seasons, fn season ->
      if season.season_number >= 1 and season.episode_count >= 1 do
        Enum.map(1..season.episode_count, fn episode_number ->
          %{season_number: season.season_number, episode_number: episode_number}
        end)
      else
        []
      end
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
