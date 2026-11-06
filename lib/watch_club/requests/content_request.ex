defmodule WatchClub.Requests.ContentRequest do
  @moduledoc """
  A request to make a piece of `Content` available on the Watch Club instance, for everybody.

  A Content has at most one, made by the first User who asks. That User becomes its first
  `RequestSubscriber`, and only its Request Subscribers are told when it becomes playable.

  If the instance has some requestable Media Sources configured (Radarr, Sonarr...)
  creating a Request will automatically create one `Media Source Request` per source (if it did not
  exist before), so that the content is automatically downloaded.
  If not, the requests will be considered "manual", meaning that we will just wait that the
  administrator finds and imports a Media for this content on its own.

  At the moment, there is no approval workflow, all requests automatically download content.
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Requests,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  use Gettext, backend: WatchClubWeb.Gettext

  import Ash.Expr

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.Changes.EnsureContentExists
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Requests.Changes.CreateMediaSourceRequests

  alias WatchClub.Requests.{
    ContentRequestSort,
    ContentRequestStatus,
    ContentRequestStatusGroup,
    MediaSourceRequest,
    RequestSubscriber
  }

  postgres do
    table "content_requests"
    repo WatchClub.Repo

    references do
      reference :requested_by, on_delete: :nilify
      reference :content, on_delete: :delete
      reference :best_source_request, on_delete: :nilify
    end
  end

  actions do
    defaults [:read, :destroy]

    create :request do
      description "Makes the Content's only Content Request, with the actor as its first Request Subscriber."

      argument :content_identity, WatchClub.Contents.ContentIdentity, allow_nil?: false

      change relate_actor(:requested_by)
      change EnsureContentExists
      change CreateMediaSourceRequests

      # The Request Subscriber's own create relates the actor
      change fn changeset, _context ->
        Ash.Changeset.manage_relationship(changeset, :subscribers, [%{}], type: :create)
      end
    end

    update :update do
      accept [:best_source_request_id]
      # This forces updates of the row, even when updating with an empty input map
      # (which is the case in UpdateContentRequest when a media has changed)
      change atomic_update(:updated_at, expr(now()))
    end

    read :for_current_user do
      description "The Content Requests the actor is a Request Subscriber of, for the My Requests page."

      argument :content_type, :atom do
        allow_nil? true
        constraints one_of: [:movie, :tv_show, :book]
      end

      argument :status_group, ContentRequestStatusGroup, allow_nil?: true

      argument :sort, ContentRequestSort do
        default ContentRequestSort.default()
      end

      pagination keyset?: true, default_limit: 25, required?: false

      filter expr(actor_subscriber?)

      prepare build(filter: expr(content.type == ^arg(:content_type))) do
        where present(:content_type)
      end

      prepare build(filter: expr(status_group == ^arg(:status_group))) do
        where present(:status_group)
      end

      # Apply the requested sort, then load the read model and the content
      # (through its `:for_view` read action).
      prepare fn query, context ->
        query |> ContentRequestSort.sort_query(Ash.Query.get_argument(query, :sort))
      end
    end
  end

  policies do
    policy actor_absent() do
      description "Content Request actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Every User sees every Content Request"
      authorize_if always()
    end

    policy action_type(:create) do
      description "Any authenticated user can request content"
      authorize_if always()
    end

    policy action_type(:update) do
      description "Only SystemActor can update Content Requests"
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action_type(:destroy) do
      description "Only the Instance Administrator can delete a Content Request"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Publish to the global content topic, since every User sees every Content Request
    # We add :content_id and :content_identity in the metadata to make
    # it easy for subscribers to know which media this is related to
    publish_all :create, ["content", "global"],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :update, ["content", "global"],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["content", "global"],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    defp add_content_identity_to_metadata(%Ash.Notifier.Notification{} = notification) do
      content = notification.data.content

      %{
        notification
        | metadata:
            notification.metadata
            |> Map.put(:content_identity, ContentIdentity.from_content(content))
            |> Map.put(:content_id, content.id)
      }
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    # Nil once that User is deleted
    belongs_to :requested_by, User do
      allow_nil? true
      attribute_writable? false
    end

    belongs_to :content, Content do
      allow_nil? false
      # Set by EnsureContentExists from the action arguments, not accepted.
      attribute_writable? false
    end

    # The most advanced MSR for this Content. Null if we don't have *arr server configured
    belongs_to :best_source_request, MediaSourceRequest do
      allow_nil? true
    end

    has_many :subscribers, RequestSubscriber
  end

  calculations do
    # The percentage of sub-contents for which medias exist and are ready to play on Watch Club
    # For movies and books, this can only be 0 or 100
    # For TV show, this is equal to the number of playable aired episodes / number of aired episodes
    calculate :percent_imported,
              :float,
              expr(
                cond do
                  content.type == :movie and count(content.movie.videos) > 0 ->
                    100.0

                  content.type == :book and
                      count(content.book.audiobooks) + count(content.book.ebooks) > 0 ->
                    100.0

                  # Guard the 0 denominator before any episode has aired
                  content.type == :tv_show and not exists(content.tv_show.episodes, aired?) ->
                    0.0

                  content.type == :tv_show ->
                    type(
                      count(content.tv_show.episodes,
                        query: [filter: expr(has_media? and aired?)]
                      ),
                      :float
                    ) * 100.0 /
                      count(content.tv_show.episodes, query: [filter: expr(aired?)])

                  # Movie and books without content
                  true ->
                    0.0
                end
              )

    calculate :status,
              ContentRequestStatus,
              expr(
                cond do
                  percent_imported == 100.0 ->
                    :completed

                  is_nil(best_source_request) ->
                    :queued

                  best_source_request.status == :not_released ->
                    :not_released

                  best_source_request.status == :needs_attention ->
                    :failed

                  # If it has been more than 5 minutes and we're still searching, we consider
                  # that the content has not been found
                  best_source_request.status == :searching and inserted_at < ago(5, :minute) ->
                    :not_found

                  best_source_request.status == :searching ->
                    :queued

                  best_source_request.status == :downloading ->
                    :downloading

                  best_source_request.status == :downloaded ->
                    :importing
                end
              ) do
      public? true
    end

    calculate :status_group,
              ContentRequestStatusGroup,
              expr(
                cond do
                  status in [:queued, :downloading, :importing] -> :in_progress
                  status == :completed -> :completed
                  status == :not_released -> :not_released
                  status == :not_found -> :not_found
                  status == :failed -> :needs_attention
                end
              ) do
      public? true
    end

    # How much the Media Source has downloaded, while it downloads or imports, in %
    calculate :download_progress,
              :float,
              expr(
                if status in [:downloading, :importing] do
                  best_source_request.download_progress
                else
                  nil
                end
              )

    calculate :actor_subscriber?, :boolean, expr(exists(subscribers, user_id == ^actor(:id)))
  end

  identities do
    identity :unique_content, [:content_id] do
      message dgettext_noop("errors", "This has already been requested")
    end
  end
end
