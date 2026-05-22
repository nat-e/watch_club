defmodule WatchClub.Media.Media do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.{Audiobook, Ebook, ImportRun, MediaType, Video}
  alias WatchClub.Shared.Changes.NormalizePath

  import Ash.Expr
  require Ash.Query

  postgres do
    table "media"
    repo WatchClub.Repo

    references do
      reference :last_successful_media_import, on_delete: :nilify, on_update: :update
    end
  end

  actions do
    defaults [:read, :destroy]

    read :under_path_prefix do
      argument :prefix, :string, allow_nil?: false

      prepare fn query, _context ->
        prefix = Ash.Query.get_argument(query, :prefix)
        Ash.Query.filter(query, expr(fragment("? LIKE ?", path, ^(prefix <> "%"))))
      end
    end

    create :create_video do
      primary? true
      accept [:path]

      argument :video, :map do
        allow_nil? false
      end

      change set_attribute(:type, :video)
      change NormalizePath
      change manage_relationship(:video, type: :create, authorize?: false)
    end

    create :create_ebook do
      accept [:path]

      argument :ebook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :ebook)
      change NormalizePath
      change manage_relationship(:ebook, type: :create, authorize?: false)
    end

    create :create_audiobook do
      accept [:path]

      argument :audiobook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :audiobook)
      change NormalizePath
      change manage_relationship(:audiobook, type: :create, authorize?: false)
    end

    update :update_video do
      description "Updates the concrete Video (and its tracks) attached to this Media without touching the Media row itself. Used by Media Imports when Refresh Metadata is on."
      require_atomic? false

      argument :video, :map do
        allow_nil? false
      end

      change fn changeset, _context ->
        # Video shares the Media's primary key. Setting `id` on the input lets
        # `manage_relationship` match it against the existing Video and update
        # in place rather than destroy + create.
        video_input =
          changeset
          |> Ash.Changeset.get_argument(:video)
          |> Map.put(:id, changeset.data.id)

        Ash.Changeset.manage_relationship(changeset, :video, video_input,
          type: :direct_control,
          authorize?: false
        )
      end
    end

    update :assign_last_successful_import do
      description "Sets the Media Import that last successfully imported this Media. Drives deletion ownership."
      require_atomic? false
      accept [:last_successful_media_import_id]
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

    policy action_type([:create, :update, :destroy]) do
      description "Only the system actor can write Media"
      authorize_if actor_attribute_equals(:system?, true)
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

    belongs_to :last_successful_media_import, ImportRun do
      allow_nil? true
      public? true
      attribute_writable? true
    end
  end

  identities do
    identity :unique_path, [:path]
  end
end
