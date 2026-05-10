defmodule WatchClub.Contents do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Contents.{
    Book,
    Content,
    ContentView,
    ExternalIdSource,
    Movie,
    MovieLocalization,
    TvShow
  }

  resources do
    resource Content do
      define :search_content, action: :search

      define :set_in_club_libraries
    end

    resource Book do
      # define :create_book, action: :create
    end

    resource Movie do
      define :create_movie, action: :create, args: [:tmdb_id]
      define :get_movie_details, action: :details, args: [:tmdb_id]
    end

    resource MovieLocalization

    resource TvShow do
    end
  end

  @spec get_context_by_external_id(ExternalIdSource.t(), String.t(), keyword()) ::
          {:ok, ContentView.t()} | {:error, term()}
  def get_context_by_external_id(external_id_source, external_id, opts \\ []) do
    result =
      Ash.ActionInput.for_action(Content, :context, %{
        external_id_source: external_id_source,
        external_ids: [external_id]
      })
      |> Ash.run_action(opts)

    case result do
      {:ok, contexts} ->
        {:ok, Map.fetch!(contexts, external_id)}

      {:error, error} ->
        {:error, error}
    end
  end
end
