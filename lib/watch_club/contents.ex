defmodule WatchClub.Contents do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Contents.{
    Book,
    Content,
    Movie,
    MovieLocalization,
    SportsEvent,
    TvShow,
    TvShowEpisode,
    TvShowEpisodeLocalization,
    TvShowLocalization
  }

  resources do
    resource Content do
      define :search_content, action: :search
      define :get_contents_in_library, action: :in_library
      define :get_library_filter_options, action: :library_filter_options

      define :get_contents_by_identities,
        action: :by_content_identities,
        args: [:content_identities]

      define :get_content_by_id, action: :read, get_by: [:id]

      define :get_content_by_identity,
        action: :by_content_identity,
        args: [:content_identity],
        get?: true

      define :create_content, action: :create, args: [:content_identity]
      define :refresh_metadata

      define :get_or_refresh_content, action: :get_or_refresh, args: [:content_identity]

      define :get_user_recently_watched, action: :user_recently_watched
    end

    resource Movie

    resource Book

    resource SportsEvent

    resource MovieLocalization

    resource TvShow

    resource TvShowEpisode do
      define :get_episodes_for_show, action: :for_show, args: [:tmdb_id]
    end

    resource TvShowLocalization
    resource TvShowEpisodeLocalization
  end
end
