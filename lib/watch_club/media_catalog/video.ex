defmodule WatchClub.MediaCatalog.Video do
  @moduledoc """
  Concrete Media for a playable video file. It holds one or more Parts of the Movie, TV Show
  Episode or Sports Event it plays, usually Part 1 of one of them, and none when it's Unmatched
  Media. It owns its video, audio, and text tracks.

  `Video.id` is the same value as its parent `Media.id` (shared primary key,
  no separate `media_id` column).

  Saving a Video builds its Scrubbing Thumbnails when its file is new or changed,
  as its File Fingerprint tells, or when they're missing. It finds its Markers
  when its file or its Parts change.

  Direct creation is reserved for Instance Administrator access; the production
  path goes through `WatchClub.MediaCatalog.create_video/2`, which uses relationship
  management to create the Video alongside its parent Media and tracks.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Markers.Changes.ScheduleDetection
  alias WatchClub.Markers.Marker
  alias WatchClub.MediaCatalog.{AudioTrack, Media, Part, TextTrack, VideoPart, VideoTrack}
  alias WatchClub.MediaCatalog.Calculations.{ToPlay, VideosAfter}
  alias WatchClub.MediaCatalog.Changes.{RelateParts, ScheduleTrickplay}

  postgres do
    table "videos"
    repo WatchClub.Repo

    references do
      reference :media, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [:file_fingerprint, :duration_seconds, :container, :bit_rate, :keyframe_seconds]

      argument :parts, {:array, :map} do
        description "The Parts it holds, each with a movie_id, tv_show_episode_id or sports_event_id, a number and an optional name"
        allow_nil? false
        default []
      end

      argument :video_tracks, {:array, :map} do
        allow_nil? false
        constraints min_length: 1
      end

      argument :audio_tracks, {:array, :map} do
        allow_nil? false
        default []
      end

      argument :text_tracks, {:array, :map} do
        allow_nil? false
        default []
      end

      change RelateParts
      change manage_relationship(:video_tracks, type: :direct_control, authorize?: false)
      change manage_relationship(:audio_tracks, type: :direct_control, authorize?: false)
      change manage_relationship(:text_tracks, type: :direct_control, authorize?: false)
      change ScheduleTrickplay
      change ScheduleDetection
    end

    # Replaces the Parts it holds
    update :attach do
      require_atomic? false

      argument :parts, {:array, :map} do
        description "Each Part it holds, as in create"
        allow_nil? false
      end

      change RelateParts
      change ScheduleDetection
    end

    update :regenerate_thumbnails_and_markers do
      description """
      Builds the Video's Scrubbing Thumbnails and finds its Markers again, even when its file
      hasn't changed
      """

      require_atomic? false
      accept []

      change {ScheduleTrickplay, always?: true}
      change {ScheduleDetection, always?: true}
    end

    update :update do
      primary? true
      require_atomic? false

      accept [:file_fingerprint, :duration_seconds, :container, :bit_rate, :keyframe_seconds]

      argument :parts, {:array, :map} do
        description "Each Part it holds, as in create"
        allow_nil? false
        default []
      end

      argument :video_tracks, {:array, :map} do
        allow_nil? false
        constraints min_length: 1
      end

      argument :audio_tracks, {:array, :map} do
        allow_nil? false
        default []
      end

      argument :text_tracks, {:array, :map} do
        allow_nil? false
        default []
      end

      change RelateParts
      change manage_relationship(:video_tracks, type: :direct_control, authorize?: false)
      change manage_relationship(:audio_tracks, type: :direct_control, authorize?: false)
      change manage_relationship(:text_tracks, type: :direct_control, authorize?: false)
      change ScheduleTrickplay
      change ScheduleDetection
    end
  end

  policies do
    policy actor_absent() do
      description "Video actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Videos"
      authorize_if always()
    end

    policy action([:create, :attach, :update, :destroy]) do
      description "Only the system actor can write Videos"
      authorize_if actor_attribute_equals(:system?, true)
    end

    policy action(:regenerate_thumbnails_and_markers) do
      description "The Instance Administrator and system actor regenerate Scrubbing Thumbnails and Markers"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  attributes do
    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      public? true
    end

    attribute :file_fingerprint, :string do
      description "Tells a changed file apart: a hash of its size and its first and last 64 KB"
      allow_nil? false
      public? true
    end

    attribute :duration_seconds, :float do
      allow_nil? true
      public? true
    end

    attribute :container, :string do
      allow_nil? true
      public? true
    end

    attribute :bit_rate, :integer do
      allow_nil? true
      public? true
      constraints min: 0
    end

    # Thousands of numbers, so only loaded on demand
    attribute :keyframe_seconds, {:array, :float} do
      description """
      Where playback can cut the file: the times of the keyframes of its first video stream, in
      seconds from the file's start. Nil for a Video no Media Import has read them for.
      """

      allow_nil? true
      public? true
      select_by_default? false
    end
  end

  relationships do
    belongs_to :media, Media do
      primary_key? true
      allow_nil? false
      define_attribute? false
      source_attribute :id
    end

    # In watching order: by TV Show Episode, then by Part number
    many_to_many :parts, Part do
      public? true
      through VideoPart
      source_attribute_on_join_resource :video_id
      destination_attribute_on_join_resource :part_id
      sort episode_rank: :asc, number: :asc, id: :asc
    end

    has_many :video_tracks, VideoTrack do
      public? true
    end

    has_one :default_video_track, VideoTrack do
      public? true
      from_many? true
      default_sort default?: :desc, stream_index: :asc
    end

    # In the file's order, which is the order of the HLS playlists: a TV finds its tracks by it.
    # Sidecar Text Tracks have no stream index.
    has_many :audio_tracks, AudioTrack do
      public? true
      sort stream_index: :asc, id: :asc
    end

    has_many :text_tracks, TextTrack do
      public? true
      sort stream_index: :asc, id: :asc
    end

    has_many :markers, Marker do
      public? true
    end
  end

  calculations do
    calculate :next_to_play, :struct, {ToPlay, which: :next} do
      description "What plays after it: the next Part, else the next TV Show Episode. Nil when nothing follows."
      constraints instance_of: ToPlay
      public? true
    end

    calculate :previous_to_play, :struct, {ToPlay, which: :previous} do
      description "What plays before it: the previous Part, else the previous TV Show Episode. Nil when nothing precedes."
      constraints instance_of: ToPlay
      public? true
    end

    calculate :videos_after, {:array, :struct}, VideosAfter do
      description "The Videos that can play after it, in order, at most 10."
      constraints items: [instance_of: __MODULE__]
      public? true
    end
  end

  aggregates do
    min :episode_rank, [:parts, :tv_show_episode], :rank do
      description "The rank of the first TV Show Episode it holds a Part of. Nil without one."
    end

    # Where the Player offers the next episode and Watch Progress stops counting
    first :credits_start_seconds, :markers, :start_seconds do
      public? true
      filter expr(kind == :credits)
    end
  end

  @doc """
  The Movie, TV Show Episode or Sports Event the Video plays, the first one for a file holding
  several, or nil for Unmatched Media. Needs its `parts` loaded with their works.
  """
  def work(%__MODULE__{parts: [part | _]}), do: Part.work(part)
  def work(%__MODULE__{parts: []}), do: nil
end
