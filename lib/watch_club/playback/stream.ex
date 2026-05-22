defmodule WatchClub.Playback.Stream do
  @moduledoc """
  A live HLS Stream associated with a `WatchClub.Playback.Session`.

  Stored in ETS via `Ash.DataLayer.Ets` — runtime-only, lost on restart.
  At most one Stream exists per Session: starting a new Stream tears down
  any previous one for the same Session and removes its on-disk cache.

  The Stream's `:media` attribute holds the loaded `WatchClub.Media.Media`
  graph (with `video.video_tracks`, `video.audio_tracks`, `video.text_tracks`)
  exactly as returned by `Session`'s `:for_playback` read. Playback actions
  resolve everything from that cached graph — no further DB hits, no probing.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playback,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.Media
  alias WatchClub.Playback.Stream.Actions

  ets do
    private? false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:session_id, :media_id, :output_dir, :media]
    end

    action :start, :struct do
      description "Start a new Stream for a Session, replacing any previous Stream the Session may have had."
      constraints instance_of: __MODULE__

      argument :session_id, :uuid_v7, allow_nil?: false

      run Actions.Start
    end

    action :close do
      description "Close the Stream identified by `stream_id` and delete its on-disk segment cache. A closed Stream is gone — there is no resume; the player must start a new Stream."
      argument :stream_id, :uuid_v7, allow_nil?: false

      run Actions.Close
    end

    action :master_playlist, :string do
      description "Return the HLS master playlist for the Stream."
      argument :stream_id, :uuid_v7, allow_nil?: false

      run Actions.MasterPlaylist
    end

    action :video_playlist, :string do
      description "Return the HLS media playlist for a video variant."
      argument :stream_id, :uuid_v7, allow_nil?: false
      argument :variant_id, :string, allow_nil?: false

      run Actions.VideoPlaylist
    end

    action :audio_playlist, :string do
      description "Return the HLS media playlist for an audio track."
      argument :stream_id, :uuid_v7, allow_nil?: false
      argument :track_id, :string, allow_nil?: false

      run Actions.AudioPlaylist
    end

    action :subtitle_playlist, :string do
      description "Return the HLS media playlist for a subtitle track."
      argument :stream_id, :uuid_v7, allow_nil?: false
      argument :track_id, :string, allow_nil?: false

      run Actions.SubtitlePlaylist
    end

    action :video_segment, :string do
      description "Return the on-disk path to a transcoded video segment, generating it if missing."
      argument :stream_id, :uuid_v7, allow_nil?: false
      argument :variant_id, :string, allow_nil?: false
      argument :segment_name, :string, allow_nil?: false

      run Actions.VideoSegment
    end

    action :audio_segment, :string do
      description "Return the on-disk path to a transcoded audio segment, generating it if missing."
      argument :stream_id, :uuid_v7, allow_nil?: false
      argument :track_id, :string, allow_nil?: false
      argument :segment_name, :string, allow_nil?: false

      run Actions.AudioSegment
    end

    action :subtitle_file, :string do
      description "Return the on-disk path to a generated subtitle file, generating it if missing."
      argument :stream_id, :uuid_v7, allow_nil?: false
      argument :track_id, :string, allow_nil?: false
      argument :file_name, :string, allow_nil?: false

      run Actions.SubtitleFile
    end
  end

  policies do
    policy actor_absent() do
      description "Stream actions require an actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "The system actor reads Streams to drive cache pruning; users go through generic actions."
      authorize_if actor_attribute_equals(:system?, true)
    end

    policy action_type([:create, :destroy]) do
      description "Direct CRUD on Streams is reserved for system actor; action implementations switch to it after authorizing the user against the Session."
      authorize_if actor_attribute_equals(:system?, true)
    end

    policy action_type(:action) do
      description "Generic action implementations re-authorize via the backing Session before acting on the Stream."
      authorize_if always()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :session_id, :uuid_v7, allow_nil?: false, public?: true
    attribute :media_id, :uuid_v7, allow_nil?: false, public?: true
    attribute :output_dir, :string, allow_nil?: false, public?: true

    attribute :media, :struct do
      allow_nil? false
      public? true
      constraints instance_of: Media
    end

    create_timestamp :inserted_at
  end
end
