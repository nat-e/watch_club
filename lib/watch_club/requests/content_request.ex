defmodule WatchClub.Requests.ContentRequest do
  @moduledoc """
  A user's request to make a piece of `Content` available on the Watch Club instance.

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

  import Ash.Expr

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.Requests.Changes.{CreateMediaSourceRequests, EnsureContentExists}

  alias WatchClub.Requests.{
    ContentRequestSort,
    ContentRequestStatusGroup,
    MediaSourceRequest
  }

  postgres do
    table "content_requests"
    repo WatchClub.Repo

    references do
      reference :user, on_delete: :delete
      reference :content, on_delete: :delete
      reference :best_source_request, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :request do
      upsert? true
      upsert_identity :unique_user_content

      argument :content_identity, WatchClub.Contents.ContentIdentity, allow_nil?: false

      change relate_actor(:user)
      change EnsureContentExists
      change CreateMediaSourceRequests
    end

    update :update do
      accept [:best_source_request_id]
      # This forces updates of the row, even when updating with an empty input map
      # (which is the case in UpdateContentRequests when a media has changed)
      change atomic_update(:updated_at, expr(now()))
    end

    read :for_current_user do
      description "The acting user's own Content Requests, for the My Requests page."

      argument :content_type, :atom do
        allow_nil? true
        constraints one_of: [:movie, :tv_show, :book]
      end

      argument :status_group, ContentRequestStatusGroup, allow_nil?: true

      argument :sort, ContentRequestSort do
        default ContentRequestSort.default()
      end

      pagination keyset?: true, default_limit: 25, required?: false

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

    read :for_content do
      argument :content_id, :uuid, allow_nil?: false

      filter expr(content_id == ^arg(:content_id))
    end

    destroy :cancel do
      primary? true

      description "Remove the acting user's own request. Touches no Media, Library Item, or Media Source Request."
    end
  end

  policies do
    policy actor_absent() do
      description "Content Request actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    # Reads are filtered to the actor's own requests; the Instance
    # Administrator can inspect all.
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
    end

    policy action_type(:create) do
      description "Any authenticated user can request content for themselves"
      authorize_if always()
    end

    policy action_type(:update) do
      description "Only SystemActor can update Content Requests"
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action_type(:destroy) do
      description "A user can cancel their own request; the Instance Administrator can cancel any"
      authorize_if expr(user_id == ^actor(:id))
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Publish to the User's content topic
    # We add :content_id and :content_identity in the metadata to make
    # it easy for subscribers to know which media this is related to
    publish_all :create, ["content", "user", :user_id],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :update, ["content", "user", :user_id],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["content", "user", :user_id],
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
    belongs_to :user, User do
      allow_nil? false
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
                  content.type == :tv_show and
                      not exists(content.tv_show.episodes, air_date <= today()) ->
                    0.0

                  content.type == :tv_show ->
                    type(
                      count(content.tv_show.episodes,
                        query: [filter: expr(has_media? and air_date <= today())]
                      ),
                      :float
                    ) * 100.0 /
                      count(content.tv_show.episodes, query: [filter: expr(air_date <= today())])

                  # Movie and books without content
                  true ->
                    0.0
                end
              )

    calculate :status_group,
              ContentRequestStatusGroup,
              expr(
                cond do
                  percent_imported == 100.0 ->
                    :completed

                  is_nil(best_source_request) ->
                    :in_progress

                  best_source_request.status == :not_released ->
                    :not_released

                  best_source_request.status == :needs_attention ->
                    :needs_attention

                  # If it has been more than 5 minutes and we're still searching, we consider
                  # that the content has not been found
                  best_source_request.status == :searching and inserted_at < ago(5, :minute) ->
                    :not_found

                  best_source_request.status in [
                    :searching,
                    :downloading,
                    :downloaded
                  ] ->
                    :in_progress
                end
              ) do
      public? true
    end
  end

  identities do
    identity :unique_user_content, [:user_id, :content_id]
  end
end
