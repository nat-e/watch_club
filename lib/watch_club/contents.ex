defmodule WatchClub.Contents do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Contents.{
    Book,
    Content,
    ContentIdentity,
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
      define :view_content_by_id, action: :for_view, get_by: [:id]
      define :create_content, action: :create, args: [:content_identity]
      define :refresh_metadata

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

  @doc """
  Creates a Content if it does not exist
  The create action is an upsert, so there is no race condition.
  """
  def get_or_create_content(%ContentIdentity{} = content_identity, actor) do
    case Content
         |> Ash.Query.filter(
           external_id_source == ^content_identity.external_id_source and
             external_id == ^content_identity.external_id
         )
         |> Ash.read_one(actor: actor) do
      {:ok, nil} ->
        create_content(content_identity, actor: actor)

      {:ok, existing} ->
        {:ok, existing}

      {:error, error} ->
        {:error, error}
    end
  end
end
