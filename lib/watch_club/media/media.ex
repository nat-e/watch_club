defmodule WatchClub.Media.Media do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Media,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.Media.{Audiobook, Ebook, MediaType, Video}
  alias WatchClub.Media.Preparations.{ApplyBrowseSort, FilterBrowseClub, FilterBrowseSearch}
  alias WatchClub.Shared.Changes.NormalizePath
  alias WatchClub.Shared.SortOrder

  postgres do
    table "media"
    repo WatchClub.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :under_path_prefix do
      argument :prefix, :string, allow_nil?: false

      prepare build(filter: expr(fragment("? LIKE ? || '%'", path, ^arg(:prefix))))
    end

    read :browse do
      description """
      Admin Media browser action.

      Returns Media filtered by media_type, club_id, and a free-text search
      across path and attached-content titles. Paginated with keyset.
      Preloads the attached-content + library + club tree so callers can
      compute the per-row "in N clubs" list in Elixir.
      """

      argument :search, :string, allow_nil?: true, default: nil
      argument :media_type, MediaType, allow_nil?: true, default: nil
      argument :club_id, :uuid_v7, allow_nil?: true, default: nil

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
                    movie: [content: [library_items: [library: :club]]],
                    tv_show_episode: [
                      tv_show: [content: [library_items: [library: :club]]]
                    ]
                  ],
                  ebook: [book: [content: [library_items: [library: :club]]]],
                  audiobook: [book: [content: [library_items: [library: :club]]]]
                ]
              )

      prepare FilterBrowseSearch

      prepare build(filter: expr(type == ^arg(:media_type))) do
        where present(:media_type)
      end

      prepare FilterBrowseClub
      prepare ApplyBrowseSort
    end

    create :create_video do
      primary? true
      accept [:path, :type]
      upsert? true
      upsert_identity :unique_path
      upsert_fields []

      argument :video, :map do
        allow_nil? false
      end

      change NormalizePath

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
    end

    create :create_ebook do
      accept [:path]
      upsert? true
      upsert_identity :unique_path
      upsert_fields []

      argument :ebook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :ebook)
      change NormalizePath

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
    end

    create :create_audiobook do
      accept [:path]
      upsert? true
      upsert_identity :unique_path
      upsert_fields []

      argument :audiobook, :map do
        allow_nil? false
      end

      change set_attribute(:type, :audiobook)
      change NormalizePath

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
      authorize_if WatchClub.Checks.IsSystemActor
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
  end

  identities do
    identity :unique_path, [:path]
  end
end
