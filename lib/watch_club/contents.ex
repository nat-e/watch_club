defmodule WatchClub.Contents do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Contents.{
    Book,
    Content,
    Movie,
    MovieLocalization,
    TvShow,
    TvShowEpisode,
    TvShowLocalization
  }

  require Ash.Query

  resources do
    resource Content do
      define :search_content, action: :search
      define :get_content_by_id, action: :read, get_by: [:id]
      define :create_movie, args: [:tmdb_id]
      define :create_tv_show, args: [:tmdb_id]
      define :refresh_tv_show, action: :refresh_tv_show, args: [:tmdb_id]

      define :set_club_libraries, action: :set_libraries
    end

    resource Movie do
      define :get_movie_details, action: :details, args: [:tmdb_id]
      define :mark_movie_watched, action: :mark_watched
      define :mark_movie_not_watched, action: :mark_not_watched
    end

    resource Book do
      define :mark_book_read, action: :mark_read
      define :mark_book_not_read, action: :mark_not_read
    end

    resource MovieLocalization

    resource TvShow do
      define :get_tv_show_details, action: :details, args: [:tmdb_id]

      define :get_tv_show_season_details,
        action: :season_details,
        args: [:tmdb_id, :season_number]

      define :mark_show_watched, action: :mark_watched
      define :mark_show_not_watched, action: :mark_not_watched
      define :mark_show_season_watched, action: :mark_season_watched
      define :mark_show_not_season_watched, action: :mark_season_not_watched
      define :mark_show_episode_watched, action: :mark_episode_watched
      define :mark_show_episode_not_watched, action: :mark_episode_not_watched
    end

    resource TvShowEpisode
    resource TvShowLocalization
  end

  @doc """
  Create a Movie if it does not exist.
  The create action is an upsert, so there is no race condition.
  """
  def get_or_create_movie(tmdb_id, actor) do
    case Content
         |> Ash.Query.filter(external_id_source == :tmdb and external_id == ^to_string(tmdb_id))
         |> Ash.read_one(actor: actor) do
      {:ok, nil} -> create_movie(tmdb_id, actor: actor)
      {:ok, existing} -> {:ok, existing}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Create a TV Show if it does not exist.
  The create action is an upsert, so there is no race condition.
  """
  def get_or_create_tv_show(tmdb_id, actor) do
    case Content
         |> Ash.Query.filter(external_id_source == :tmdb and external_id == ^to_string(tmdb_id))
         |> Ash.Query.load(tv_show: [:episodes])
         |> Ash.read_one(actor: actor) do
      {:ok, nil} -> create_tv_show(tmdb_id, actor: actor)
      {:ok, existing} -> {:ok, existing}
      {:error, error} -> {:error, error}
    end
  end
end
