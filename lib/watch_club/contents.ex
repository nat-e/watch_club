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

  resources do
    resource Content do
      define :search_content, action: :search
      define :create_movie, args: [:tmdb_id]
      define :create_tv_show, args: [:tmdb_id]
      define :refresh_tv_show, action: :refresh_tv_show, args: [:tmdb_id]

      define :set_club_libraries, action: :set_libraries
    end

    resource Movie do
      define :get_movie_details, action: :details, args: [:tmdb_id]
    end

    resource Book
    resource MovieLocalization

    resource TvShow do
      define :get_tv_show_details, action: :details, args: [:tmdb_id]

      define :get_tv_show_season_details,
        action: :season_details,
        args: [:tmdb_id, :season_number]
    end

    resource TvShowEpisode
    resource TvShowLocalization
  end
end
