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

  alias WatchClub.Contents.Changes.EnsureContentExists
  alias WatchClub.MediaCatalog.Changes.{AttachVideo, SetContent}
  alias WatchClub.MediaSources.Source
  alias WatchClub.Requests.Changes.UpdateContentRequest
  alias WatchClub.Shared.Changes.NormalizePath
  alias WatchClub.Shared.SortOrder

  postgres do
    table "media"
    repo WatchClub.Repo

    references do
      reference :content, on_delete: :restrict, index?: true

      # Deleting a Media Source deletes its Media through `destroy` first, which removes their
      # files on disk. The `unique_path_per_media_source` index starts with this column.
      reference :media_source, on_delete: :delete
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

    update :match do
      description """
      The Instance Administrator's Manual Match of a Video: a Movie file to a Movie, a TV Show
      Episode file to an episode of a TV Show, a Sports Event file to a Sports Event. Creates the
      Content when WatchClub doesn't have it.
      """

      require_atomic? false

      argument :content_identity, ContentIdentity do
        allow_nil? false

        description "The Content of the file's Media Type, or the TV Show of a TV Show Episode file"
      end

      argument :season_number, :integer, description: "For a TV Show Episode file"
      argument :episode_number, :integer, description: "For a TV Show Episode file"

      change set_attribute(:manually_matched?, true)
      change EnsureContentExists
      change AttachVideo
      change UpdateContentRequest
      change WatchClub.Markers.Changes.ScheduleDetection
    end

    update :unmatch do
      description """
      Makes a Video Unmatched Media, removing its Manual Match. Media Imports of unmatched files
      and webhooks match it again.
      """

      require_atomic? false

      change set_attribute(:manually_matched?, false)
      change set_attribute(:content_id, nil)
      change AttachVideo
      change UpdateContentRequest
    end

    read :browse do
      description """
      The Media Browser's list: the Media matching a search, a Media Type and whether they're
      Unmatched, sorted by date added or by title. Always one page at a time, with the total.
      """

      argument :search, :string do
        description """
        Keeps the Media where each of its words is in the path or the title, in any order. Words
        such as `s1`, `e01` or `s01e02` match the TV Show Episode's season and episode numbers.
        """
      end

      argument :media_type, MediaType
      argument :unmatched?, :boolean, allow_nil?: false, default: false

      argument :sort_by, :atom do
        allow_nil? false
        default :added
        constraints one_of: [:added, :title]
      end

      argument :sort_order, SortOrder do
        allow_nil? false
        default :desc
      end

      pagination offset?: true, countable: :by_default

      prepare FilterBrowseSearch, where: present(:search)
      prepare build(filter: expr(type == ^arg(:media_type))), where: present(:media_type)
      prepare build(filter: expr(is_nil(content_id))), where: argument_equals(:unmatched?, true)
      prepare ApplyBrowseSort
    end

    action :count_unmatched, :integer do
      description "How many Unmatched Media `browse` finds with this search and Media Type"

      argument :search, :string
      argument :media_type, MediaType

      run fn input, context ->
        __MODULE__
        |> Ash.Query.for_read(
          :browse,
          Map.put(input.arguments, :unmatched?, true),
          Ash.Scope.to_opts(context)
        )
        |> Ash.count()
      end
    end

    create :create_video do
      primary? true
      accept [:media_source_id, :path, :type]
      upsert? true
      upsert_identity :unique_path_per_media_source
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
      change WatchClub.Markers.Changes.ScheduleDetection
    end

    create :create_ebook do
      accept [:media_source_id, :path]
      upsert? true
      upsert_identity :unique_path_per_media_source
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
      accept [:media_source_id, :path]
      upsert? true
      upsert_identity :unique_path_per_media_source
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
      change WatchClub.Markers.Changes.DeleteFingerprints
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

    policy action(:count_unmatched) do
      description "Any authenticated actor can count the Unmatched Media"
      authorize_if always()
    end

    policy action([:create_video, :create_ebook, :create_audiobook, :change_path]) do
      description "Only the system actor can create Media or move it"
      authorize_if WatchClub.Checks.IsSystemActor
    end

    policy action([:match, :unmatch]) do
      description "Only the Instance Administrator matches Media by hand"
      authorize_if actor_attribute_equals(:administrator?, true)
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

    publish_all :update, ["content", "global"],
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

    # Media Imports and webhooks keep a Manual Match
    attribute :manually_matched?, :boolean do
      allow_nil? false
      default false
      public? true
      source :is_manually_matched
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

    belongs_to :media_source, Source do
      allow_nil? false
      public? true
    end
  end

  identities do
    # Media Sources that cover the same file each have their own Media
    identity :unique_path_per_media_source, [:media_source_id, :path]
  end
end
