defmodule WatchClub.Accounts.UserSettings do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.{TrackLanguage, User, UserLocale}

  postgres do
    table "user_settings"
    repo WatchClub.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [
      :read,
      update: [
        :locale,
        :audio_language,
        :subtitle_language,
        :languages_without_subtitles,
        :prefer_sdh?
      ]
    ]

    create :create do
      primary? true
      accept [:locale]

      # Subtitles in the language of the User's Locale, except when the audio is already in it
      change before_action(fn changeset, _context ->
               language =
                 changeset
                 |> Ash.Changeset.get_attribute(:locale)
                 |> UserLocale.track_language()

               Ash.Changeset.force_change_attributes(changeset,
                 subtitle_language: language,
                 languages_without_subtitles: [language]
               )
             end)
    end
  end

  policies do
    policy action([:read, :update]) do
      description "Only actor can access their settings"
      authorize_if relates_to_actor_via(:user)
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name WatchClub.PubSub

    publish :update, ["user", :user_id]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :locale, UserLocale do
      allow_nil? false
      public? true
    end

    # The types own the valid values, the Settings form localizes their errors
    attribute :audio_language, :atom do
      description "The language the User wants to hear: the Content's original language or a Track Language."
      allow_nil? false
      default :original
      public? true
      constraints one_of: [:original | TrackLanguage.values()]
    end

    attribute :subtitle_language, TrackLanguage do
      description "The language of the subtitles the User wants, or no subtitles when nil."
      allow_nil? true
      public? true
    end

    attribute :languages_without_subtitles, {:array, TrackLanguage} do
      description "The audio languages the User watches without subtitles."
      allow_nil? false
      default []
      public? true
    end

    attribute :prefer_sdh?, :boolean do
      description "Whether the User prefers SDH Text Tracks."
      allow_nil? false
      default false
      public? true
      source :prefer_sdh
    end

    timestamps()
  end

  relationships do
    belongs_to :user, User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_user, [:user_id]
  end
end
