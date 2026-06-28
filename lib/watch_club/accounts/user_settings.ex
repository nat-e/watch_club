defmodule WatchClub.Accounts.UserSettings do
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias WatchClub.Accounts.{User, UserLocale}

  postgres do
    table "user_settings"
    repo WatchClub.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, create: [:locale], update: [:locale]]
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
