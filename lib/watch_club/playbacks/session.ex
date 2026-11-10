defmodule WatchClub.Playbacks.Session do
  @moduledoc """
  What a User is watching right now. Aggregate root of the Playback domain: it owns its
  Playbacks, and a User has at most one active Playback Session.

  It plays on one Screen at a time, a Player or a TV, which reports where it's at. A Screen is a
  live connection, never stored: `screen_id` only names the one holding the Playback Session, and
  `tv_name` is set while it's a TV. A Screen that no longer holds it gets a stale record error.

  A Screen's reports name the Playback they're about, so a late one about an earlier Playback
  fails too.

  Every change is published on the `playback_session:<user id>` topic, and the Remote's commands
  for the TV, as `{:tv_command, command, position_seconds}`, on `tv:<id>`. `:watching_now` lists
  who is Watching Now.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Content, TvShowEpisode}
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Playback.SegmentCache
  alias WatchClub.Playbacks.Session.{Actions, Changes}

  postgres do
    table "playback_sessions"
    repo WatchClub.Repo

    identity_wheres_to_sql one_active_per_user: "ended_at IS NULL"

    references do
      reference :started_by, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    read :active do
      description "The actor's active Playback Session, if any."
      get? true
      filter expr(started_by_id == ^actor(:id) and is_nil(ended_at))
    end

    action :play, :struct do
      description "Play the Media in the actor's active Playback Session, or in a new one."
      constraints instance_of: __MODULE__
      transaction? true

      argument :media_id, :uuid_v7, allow_nil?: false
      argument :screen_id, :string, allow_nil?: false, description: "The Player playing it"

      run Actions.Play
    end

    create :start do
      description "Starts the actor's active Playback Session. Used by :play."
      accept []
      change relate_actor(:started_by)
    end

    update :play_media do
      description "Ends the current Playback and starts one for the Media. Used by :play."
      require_atomic? false

      argument :media_id, :uuid_v7, allow_nil?: false
      argument :screen_id, :string, allow_nil?: false

      change get_and_lock_for_update()
      change Changes.PlayMedia
    end

    update :play_next do
      description "Once the Playback finished, plays the next available TV Show Episode on the same Screen, or ends the Playback Session when nothing follows."

      require_atomic? false
      argument :screen_id, :string, allow_nil?: false
      argument :playback_id, :uuid_v7, allow_nil?: false

      change get_and_lock_for_update()
      change filter(expr(is_nil(ended_at) and screen_id == ^arg(:screen_id)))
      change Changes.PlayNext
    end

    update :heartbeat do
      description "The Screen reports where it's at in the Playback, which keeps the actor's Watch Progress up to date."

      require_atomic? false

      argument :screen_id, :string, allow_nil?: false
      argument :playback_id, :uuid_v7, allow_nil?: false
      argument :position_seconds, :float, allow_nil?: false
      argument :paused?, :boolean, allow_nil?: false

      change filter(expr(is_nil(ended_at) and screen_id == ^arg(:screen_id)))
      change filter(expr(exists(playbacks, id == ^arg(:playback_id) and is_nil(ended_at))))
      change set_attribute(:position_seconds, arg(:position_seconds))
      change set_attribute(:paused?, arg(:paused?))
      change set_attribute(:last_heartbeat_at, &DateTime.utc_now/0)
      change Changes.RecordWatchProgress
    end

    update :pick_tracks do
      description "Switches the Playback, while current, to these tracks. No Text Track turns subtitles off."

      require_atomic? false

      argument :playback_id, :uuid_v7, allow_nil?: false
      argument :audio_track_id, :uuid_v7
      argument :text_track_id, :uuid_v7

      change filter(expr(exists(playbacks, id == ^arg(:playback_id) and is_nil(ended_at))))
      change Changes.PickTracks
    end

    update :cast do
      description "The TV becomes the Screen, unless another Screen took the Playback Session since the Player cast it."

      argument :screen_id, :string, allow_nil?: false, description: "The TV"
      argument :tv_name, :string, allow_nil?: false
      argument :from_screen_id, :string, allow_nil?: false, description: "The Player that cast"

      change filter(
               expr(
                 is_nil(ended_at) and
                   (is_nil(screen_id) or screen_id in [^arg(:screen_id), ^arg(:from_screen_id)])
               )
             )

      change set_attribute(:screen_id, arg(:screen_id))
      change set_attribute(:tv_name, arg(:tv_name))
      change set_attribute(:last_heartbeat_at, &DateTime.utc_now/0)
    end

    update :leave do
      description "The TV disconnected: the Playback Session has no Screen until it comes back."

      argument :screen_id, :string, allow_nil?: false

      change filter(expr(is_nil(ended_at) and screen_id == ^arg(:screen_id)))
      change set_attribute(:screen_id, nil)
      change set_attribute(:tv_name, nil)
    end

    update :control do
      description "Sends the Remote's command to the TV. It changes nothing: the TV reports what it did."

      argument :command, :atom do
        allow_nil? false
        constraints one_of: [:play, :pause, :seek]
      end

      argument :position_seconds, :float, description: "Where to seek"

      change filter(expr(is_nil(ended_at) and not is_nil(tv_name)))
    end

    update :end do
      description "Ends the Playback Session and its current Playback, which stops casting."
      require_atomic? false

      argument :reason, :atom do
        description "Counted in the `[:watch_club, :playback_session, :end]` telemetry event"
        default :stopped
        constraints one_of: [:stopped, :abandoned]
      end

      change filter(expr(is_nil(ended_at)))
      change set_attribute(:ended_at, &DateTime.utc_now/0)
      change Changes.EndCurrentPlayback

      change after_action(fn changeset, session, _context ->
               :telemetry.execute([:watch_club, :playback_session, :end], %{count: 1}, %{
                 reason: changeset.arguments.reason
               })

               {:ok, session}
             end)
    end

    action :end_abandoned_sessions do
      description "Ends every Playback Session without a Screen for two minutes, then removes the segment cache of every ended Playback."

      run fn _input, context ->
        __MODULE__
        |> Ash.Query.filter(is_nil(ended_at) and last_heartbeat_at < ago(2, :minute))
        |> Ash.bulk_update!(:end, %{reason: :abandoned},
          strategy: :stream,
          notify?: true,
          scope: context
        )

        SegmentCache.prune_stale!()
        :ok
      end
    end

    action :watching_now, {:array, :map} do
      description "The other Users Watching Now, the latest first: each one's User, and the Content and TV Show Episode they play, but not their Playback Sessions."

      constraints items: [
                    fields: [
                      user: [type: :struct, allow_nil?: false, constraints: [instance_of: User]],
                      content: [
                        type: :struct,
                        allow_nil?: false,
                        constraints: [instance_of: Content]
                      ],
                      tv_show_episode: [type: :struct, constraints: [instance_of: TvShowEpisode]]
                    ]
                  ]

      run fn _input, context ->
        # The Screen reports every 5 seconds, paused included. Unmatched Media has no Content.
        __MODULE__
        |> Ash.Query.filter(
          started_by_id != ^context.actor.id and is_nil(ended_at) and
            last_heartbeat_at > ago(30, :second) and
            exists(playbacks, is_nil(ended_at) and not is_nil(media.content_id))
        )
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([
          :started_by,
          current_playback: [
            media: [
              content: [:title, :poster_path],
              video: [tv_show_episode: [:formatted_episode_number]]
            ]
          ]
        ])
        |> Ash.read!(Ash.Context.to_opts(context, authorize?: false))
        |> Enum.map(fn %{current_playback: %{media: media}} = session ->
          %{
            user: session.started_by,
            content: media.content,
            tv_show_episode: media.video && media.video.tv_show_episode
          }
        end)
        |> then(&{:ok, &1})
      end
    end
  end

  policies do
    policy action([:play, :start]) do
      description "Any User can play; access to the Media is checked when its Playback starts."
      authorize_if actor_present()
    end

    policy action_type(:read) do
      description "Only the User who started a Playback Session, the Instance Administrator and the system actor can see it"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via(:started_by)
    end

    policy action(:watching_now) do
      description "Every User sees who is Watching Now and what they play"
      authorize_if actor_present()
    end

    policy action_type(:update) do
      description "Only the User who started a Playback Session controls it"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if relates_to_actor_via(:started_by)
    end

    policy action(:end_abandoned_sessions) do
      description "Only the system actor ends abandoned Playback Sessions"
      authorize_if WatchClub.Checks.IsSystemActor
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish_all :create, ["playback_session", :started_by_id]
    publish_all :update, ["playback_session", :started_by_id], except: [:control]

    publish :control, ["tv", :id],
      transform: fn %{changeset: %{arguments: arguments}} ->
        {:tv_command, arguments.command, arguments[:position_seconds]}
      end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :screen_id, :string do
      description "The Player or the TV it plays on. Nil once a TV disconnected."
      public? true
    end

    attribute :tv_name, :string do
      description "The TV it plays on, nil while it plays in a Player."
      public? true
    end

    attribute :position_seconds, :float do
      description "Where the Screen is at in the current Playback."
      allow_nil? false
      default 0.0
      public? true
    end

    attribute :paused?, :boolean do
      source :is_paused
      allow_nil? false
      default false
      public? true
    end

    attribute :last_heartbeat_at, :utc_datetime_usec do
      description "When its Screen last reported, to end it two minutes after the last one left."
      allow_nil? false
      default &DateTime.utc_now/0
      public? true
    end

    attribute :ended_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :started_by, User do
      allow_nil? false
    end

    has_many :playbacks, Playback

    has_one :current_playback, Playback do
      from_many? true
      public? true
      filter expr(is_nil(ended_at))
    end
  end

  identities do
    identity :one_active_per_user, [:started_by_id] do
      where expr(is_nil(ended_at))
      message dgettext_noop("errors", "Something else started playing at the same time")
    end
  end
end
