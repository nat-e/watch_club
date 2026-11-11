defmodule WatchClub.MediaCatalog.Part do
  @moduledoc """
  A piece of a Movie, TV Show Episode or Sports Event, in watching order. Most have one Part, the
  whole of it; a TV Show Episode that TMDB keeps whole while Sonarr has each half in its own file
  has two. A Video contains one or more Parts, and Videos containing the same Part are copies.

  WatchClub only knows the Parts it has files for: a Part no Video contains anymore is left out
  of its Movie's, TV Show Episode's or Sports Event's `parts`, and comes back with its next file.
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
      # The unique_number_per_work index starts with movie_id
      reference :movie, on_delete: :restrict
      reference :tv_show_episode, on_delete: :restrict, index?: true
      reference :sports_event, on_delete: :restrict, index?: true
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

    # The name its source gives it, such as Sportarr's Main Card
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
      # The oldest copy first
      sort id: :asc
    end
  end

  identities do
    identity :unique_number_per_work, [:movie_id, :tv_show_episode_id, :sports_event_id, :number] do
      nils_distinct? false
    end
  end

  @doc "The Movie, TV Show Episode or Sports Event of a Part, loaded."
  def work(%__MODULE__{} = part), do: part.movie || part.tv_show_episode || part.sports_event

  @doc "The id of the Movie, TV Show Episode or Sports Event of a Part."
  def work_id(%__MODULE__{} = part),
    do: part.movie_id || part.tv_show_episode_id || part.sports_event_id
end
