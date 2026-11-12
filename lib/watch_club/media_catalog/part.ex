defmodule WatchClub.MediaCatalog.Part do
  @moduledoc """
  A numbered piece of a Movie, TV Show Episode or Sports Event. Most have only Part 1, the whole of
  it. A two-part episode that TMDB lists as one, but that Sonarr splits in two files, has two.

  Parts are created when a Video is linked to them, through the Video's `parts` argument. Videos
  holding the same Part are copies. A Part that no Video holds stays, but its work's `parts`
  leave it out. Deleting the work deletes its Parts, unless a Video holds one.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Contents.{Movie, SportsEvent, TvShowEpisode}
  alias WatchClub.MediaCatalog.{Video, VideoPart}

  postgres do
    table "parts"
    repo WatchClub.Repo

    references do
      # No index: the unique_number_per_work index starts with movie_id
      reference :movie, on_delete: :delete
      reference :tv_show_episode, on_delete: :delete, index?: true
      reference :sports_event, on_delete: :delete, index?: true
    end

    check_constraints do
      check_constraint [:movie_id, :tv_show_episode_id, :sports_event_id],
        name: "parts_one_work_check",
        check: "num_nonnulls(movie_id, tv_show_episode_id, sports_event_id) = 1",
        message: "A Part belongs to one Movie, TV Show Episode or Sports Event"
    end
  end

  actions do
    defaults [:read]

    create :upsert do
      description "Finds or creates the Part of this number of a Movie, TV Show Episode or Sports Event"
      upsert? true
      upsert_identity :unique_number_per_work
      upsert_fields [:name]
      accept [:movie_id, :tv_show_episode_id, :sports_event_id, :number, :name]
    end
  end

  policies do
    policy actor_absent() do
      description "Part actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Parts"
      authorize_if always()
    end

    policy action_type(:create) do
      description "Only the system actor can write Parts"
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :number, :integer do
      allow_nil? false
      public? true
      constraints min: 1
    end

    # A name from its source, such as Sportarr's Main Card. Usually nil
    attribute :name, :string do
      public? true
    end
  end

  relationships do
    belongs_to :movie, Movie do
      public? true
    end

    belongs_to :tv_show_episode, TvShowEpisode do
      public? true
    end

    belongs_to :sports_event, SportsEvent do
      public? true
    end

    many_to_many :videos, Video do
      public? true
      through VideoPart
      source_attribute_on_join_resource :part_id
      destination_attribute_on_join_resource :video_id
      # Oldest first: ids are UUIDv7, which sort by creation time
      sort id: :asc
    end
  end

  calculations do
    calculate :episode_rank, :integer, expr(tv_show_episode.rank) do
      description "The rank of its TV Show Episode in its TV Show, to order the Parts of a file. Nil for other works."
    end
  end

  identities do
    identity :unique_number_per_work, [:movie_id, :tv_show_episode_id, :sports_event_id, :number] do
      nils_distinct? false
    end
  end

  @doc """
  The Movie, TV Show Episode or Sports Event a Part belongs to. Load all three relationships
  first: an unloaded one would be returned instead.
  """
  def work(%__MODULE__{} = part), do: part.movie || part.tv_show_episode || part.sports_event

  @doc "The id of the Movie, TV Show Episode or Sports Event a Part belongs to."
  def work_id(%__MODULE__{} = part),
    do: part.movie_id || part.tv_show_episode_id || part.sports_event_id
end
