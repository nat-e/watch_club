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

      define :get_or_refresh_content,
        action: :get_or_refresh,
        args: [:content_identity],
        functions: [:subject]

      define :get_user_recently_watched, action: :user_recently_watched
    end

    resource Movie

    resource Book

    resource MovieLocalization

    resource TvShow

    resource TvShowEpisode do
      define :get_episodes_for_show, action: :for_show, args: [:tmdb_id]
    end

    resource TvShowLocalization
    resource TvShowEpisodeLocalization
  end

  @doc """
  Returns the stored Content for an identity, creating it from its Metadata Provider when missing.

  Metadata older than `:max_age` is refreshed when the Metadata Provider answers. `:max_age`
  is non-negative seconds from this call, defaults to one day, and accepts `:infinity` to
  never refresh stored Content. Concurrent calls for the same Content share one fetch.

  A Metadata Provider failure returns stored Content unchanged, or an error when none is
  stored. Unexpected failures exit the caller. `:load` applies with the caller's actor.
  """
  @spec get_or_refresh_content(ContentIdentity.t(), keyword()) ::
          {:ok, Content.t()} | {:error, Ash.Error.t()}
  def get_or_refresh_content(identity, opts \\ []) do
    {arguments, opts} = Keyword.split(opts, [:max_age])

    identity
    |> input_to_get_or_refresh_content(Map.new(arguments), opts)
    |> Ash.run_action(opts)
  end

  @doc "The raising version of `get_or_refresh_content/2`."
  @spec get_or_refresh_content!(ContentIdentity.t(), keyword()) :: Content.t()
  def get_or_refresh_content!(identity, opts \\ []) do
    {arguments, opts} = Keyword.split(opts, [:max_age])

    identity
    |> input_to_get_or_refresh_content(Map.new(arguments), opts)
    |> Ash.run_action!(opts)
  end
end
