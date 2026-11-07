defmodule WatchClub.MediaCatalog.Media do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Contents.{Content, ContentIdentity}
  alias WatchClub.MediaCatalog.{Audiobook, Ebook, MediaType, Video}

  alias WatchClub.MediaCatalog.Preparations.{
    ApplyBrowseSort,
    FilterBrowseSearch
  }

  alias WatchClub.MediaCatalog.Changes.SetContent
  alias WatchClub.Requests.Changes.UpdateContentRequest
  alias WatchClub.Shared.Changes.NormalizePath
  alias WatchClub.Shared.SortOrder

  postgres do
    table "media"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    # Move a Media to a new path (e.g. a Radarr/Sonarr rename). Content and
    # tracks are unchanged — only the file location moves.
    update :change_path do
      accept [:path]
      change NormalizePath
    end

    read :under_path_prefix do
      argument :prefix, :string, allow_nil?: false

      prepare build(filter: expr(string_starts_with(path, ^arg(:prefix))))
    end

    read :browse do
      description """
      Admin Media browser action.

      Returns Media filtered by media_type and a free-text search across path
      and attached-content titles. Paginated with keyset.
      """

      argument :search, :string, allow_nil?: true, default: nil
      argument :media_type, MediaType, allow_nil?: true, default: nil

      argument :sort_by, :atom do
        allow_nil? false
        default :imported_at
        constraints one_of: [:imported_at, :path]
      end

      argument :sort_order, SortOrder do
        allow_nil? false
        default :desc
      end

      pagination keyset?: true, default_limit: 50, required?: false

      prepare build(
                load: [
                  video: [
                    :default_video_track,
                    :audio_tracks,
                    :text_tracks,
                    movie: [:content],
                    tv_show_episode: [tv_show: [:content]]
                  ],
                  ebook: [book: [:content]],
                  audiobook: [book: [:content]]
                ]
              )

      prepare FilterBrowseSearch

      prepare build(filter: expr(type == ^arg(:media_type))) do
        where present(:media_type)
      end

      prepare ApplyBrowseSort
    end

    create :create_video do
      primary? true
      accept [:path, :type]
      upsert? true
      upsert_identity :unique_path
      upsert_fields [:content_id]

      argument :video, :map do
        allow_nil? false
      end

      change NormalizePath
      change {SetContent, attachment: :video}

      change fn changeset, _ctx ->
        video_input =
          changeset
          |> Ash.Changeset.get_argument(:video)
          # shared PK — needed for :direct_control to match the existing Video on the upsert path
          |> Map.put(:id, changeset.data.id)

        Ash.Changeset.manage_relationship(changeset, :video, video_input,
          type: :direct_control,
          authorize?: false
        )
      end

      change UpdateContentRequest
      change WatchClub.MediaCatalog.Changes.ScheduleTrickplay
    end

    create :create_ebook do
      accept [:path]
      upsert? true
      upsert_identity :unique_path
      upsert_fields [:content_id]

      argument :ebook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :ebook)
      change NormalizePath
      change {SetContent, attachment: :ebook}

      change fn changeset, _ctx ->
        ebook_input =
          changeset
          |> Ash.Changeset.get_argument(:ebook)
          # shared PK — needed for :direct_control to match the existing ebook on the upsert path
          |> Map.put(:id, changeset.data.id)

        Ash.Changeset.manage_relationship(changeset, :ebook, ebook_input,
          type: :direct_control,
          authorize?: false
        )
      end

      change UpdateContentRequest
    end

    create :create_audiobook do
      accept [:path]
      upsert? true
      upsert_identity :unique_path
      upsert_fields [:content_id]

      argument :audiobook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :audiobook)
      change NormalizePath
      change {SetContent, attachment: :audiobook}

      change fn changeset, _ctx ->
        audiobook_input =
          changeset
          |> Ash.Changeset.get_argument(:audiobook)
          # shared PK — needed for :direct_control to match the existing audiobook on the upsert path
          |> Map.put(:id, changeset.data.id)

        Ash.Changeset.manage_relationship(changeset, :audiobook, audiobook_input,
          type: :direct_control,
          authorize?: false
        )
      end

      change UpdateContentRequest
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change UpdateContentRequest
      change WatchClub.MediaCatalog.Changes.DeleteTrickplay
    end
  end

  policies do
    policy actor_absent() do
      description "Media actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Media"
      authorize_if always()
    end

    policy action_type([:create, :update]) do
      description "Only the system actor can create or update Media"
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action_type(:destroy) do
      description "The system actor or an instance administrator can destroy Media"
      authorize_if WatchClub.Checks.IsSystemActor
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    # Publish to the global content topic
    # We add :content_id and :content_identity in the metadata to make
    # it easy for subscribers to know which media this is related to.
    # The Content fields are listed because PubSub only selects the primary key
    # of related records otherwise.
    publish_all :create, ["content", "global"],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    publish_all :destroy, ["content", "global"],
      load: [content: [:type, :external_id_source, :external_id]],
      transform: &add_content_identity_to_metadata/1

    defp add_content_identity_to_metadata(%Ash.Notifier.Notification{} = notification) do
      case notification.data.content do
        nil ->
          notification

        content ->
          %{
            notification
            | metadata:
                notification.metadata
                |> Map.put(:content_identity, ContentIdentity.from_content(content))
                |> Map.put(:content_id, content.id)
          }
      end
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :path, :string do
      allow_nil? false
      public? true
    end

    attribute :type, MediaType do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    has_one :video, Video do
      destination_attribute :id
    end

    has_one :ebook, Ebook do
      destination_attribute :id
    end

    has_one :audiobook, Audiobook do
      destination_attribute :id
    end

    # The Content of the Movie, TV Show Episode or Book this Media is attached to.
    # nil for an unmatched Media.
    belongs_to :content, Content
  end

  identities do
    identity :unique_path, [:path]
  end
end
