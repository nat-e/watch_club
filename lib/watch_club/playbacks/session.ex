defmodule WatchClub.Playbacks.Session do
  @moduledoc """
  Aggregate root for the Playback domain. Owns the lifecycle of its Playbacks.

  All public lifecycle actions live here: starting a Playback Session,
  switching to a new Playback inside it, heartbeating the current Playback and
  ending the Playbacks whose Player is no longer active. `:watching_now` lists
  who is Watching Now.
  Callers load `:active_playback` with the fields they need.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  import Ash.Expr

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Content, TvShowEpisode}
  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.Playback.SegmentCache
  alias WatchClub.Playbacks.Session.Changes

  postgres do
    table "playback_sessions"
    repo WatchClub.Repo

    references do
      reference :started_by, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :start do
      description "Create a Playback Session and start its first Playback for the selected Media."
      argument :media_id, :uuid_v7, allow_nil?: false

      change relate_actor(:started_by)
      change manage_relationship(:media_id, :playbacks, type: :create, value_is_key: :media_id)
    end

    update :start_new_playback do
      description "End the current Playback on this Session and start a new one for the selected Media."

      require_atomic? false
      argument :media_id, :uuid_v7, allow_nil?: false

      change Changes.EndCurrentPlayback
      change Changes.StartPlayback
    end

    update :heartbeat do
      description "Heartbeat the Session's current Playback, updating its last active time and the actor's Watch Progress from the reported position."

      require_atomic? false
      argument :position_seconds, :float, allow_nil?: true

      change Changes.BumpCurrentPlayback
    end

    action :watching_now, {:array, :map} do
      description "The other Users Watching Now, the latest first: each one's User, and the Content and TV Show Episode their Player plays, but not their Playback Sessions."

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
        # The Player heartbeats every 5 seconds, paused included. Unmatched Media has no Content.
        __MODULE__
        |> Ash.Query.filter(
          started_by_id != ^context.actor.id and
            exists(
              playbacks,
              is_nil(ended_at) and last_active_at > ago(30, :second) and
                not is_nil(media.content_id)
            )
        )
        # Once per User, with the Session they started last
        |> Ash.Query.distinct(:started_by_id)
        |> Ash.Query.distinct_sort(inserted_at: :desc)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.Query.load([
          :started_by,
          active_playback: [
            media: [
              content: [:implementation],
              video: [tv_show_episode: [:formatted_episode_number]]
            ]
          ]
        ])
        |> Ash.read!(Ash.Context.to_opts(context, authorize?: false))
        |> Enum.map(fn %{active_playback: %{media: media}} = session ->
          %{
            user: session.started_by,
            content: media.content,
            tv_show_episode: media.video && media.video.tv_show_episode
          }
        end)
        |> then(&{:ok, &1})
      end
    end

    action :end_inactive_playbacks do
      description "End every current Playback whose Player has sent no heartbeat for six hours, then remove the segment cache of every ended Playback."

      run fn _input, context ->
        Playback
        |> Ash.Query.filter(is_nil(ended_at) and last_active_at < ago(6, :hour))
        |> Ash.bulk_update!(:end, %{}, strategy: :stream, scope: context)

        SegmentCache.prune_stale!()
        :ok
      end
    end
  end

  policies do
    policy action(:start) do
      description "A User can start a Playback Session; access to its Media is checked when the first Playback is created."
      authorize_if actor_present()
    end

    policy action_type(:read) do
      description "Only the starting User and Instance Administrator can access Playback Sessions"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via(:started_by)
    end

    policy action(:watching_now) do
      description "Every User sees who is Watching Now and what they play"
      authorize_if actor_present()
    end

    policy action(:end_inactive_playbacks) do
      description "Only the system actor can end inactive Playbacks"
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action_type(:update) do
      description "Only the starting User and the Instance Administrator can update a playback session"
      authorize_if actor_attribute_equals(:administrator?, true)
      authorize_if relates_to_actor_via(:started_by)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :started_by, User do
      allow_nil? false
    end

    has_many :playbacks, Playback

    has_one :active_playback, Playback do
      from_many? true
      public? true
      filter expr(is_nil(ended_at))
    end
  end
end
