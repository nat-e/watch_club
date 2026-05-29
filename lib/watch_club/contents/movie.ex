defmodule WatchClub.Contents.Movie do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Contents,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.{Content, ContentView, MovieLocalization}
  alias WatchClub.MediaCatalog.Video

  postgres do
    table "movies"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :delete, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy, update: []]

    create :create do
      primary? true
      argument :localizations, {:array, :map}, allow_nil?: false
      change manage_relationship(:localizations, type: :direct_control)
    end

    action :details, :struct do
      constraints instance_of: ContentView
      argument :tmdb_id, :integer, allow_nil?: false

      run WatchClub.Contents.Actions.GetMovieDetails
    end
  end

  policies do
    policy actor_absent() do
      description "Movie actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action([:read, :details]) do
      description "Movie metadata and details are visible to authenticated users"
      authorize_if always()
    end
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :content, Content do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end

    has_many :localizations, MovieLocalization

    has_one :best_localization, MovieLocalization do
      from_many? true
    end

    has_many :videos, Video
  end

  identities do
    identity :unique_content, [:id]
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(movie) do
      case movie.content do
        %Ash.NotLoaded{} ->
          "[Movie] id:#{movie.id}"

        %{original_title: title, release_date: %Date{year: year}} ->
          "[Movie] #{title} (#{year})"

        %{original_title: title} ->
          "[Movie] #{title}"
      end
    end
  end
end
