defmodule WatchClub.Instance.InstanceSettings do
  @moduledoc """
  Configuration of the self-hosted instance for this installation.

  There is exactly one row: it is seeded at installation time and only ever
  updated. The single-row invariant is enforced at the database level by the
  `singleton` column (a unique identity restricted to `true` by a check constraint).
  """
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Instance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "instance_settings"
    repo WatchClub.Repo

    check_constraints do
      check_constraint :singleton,
        check: "singleton = true",
        name: "instance_settings_singleton_check"
    end
  end

  actions do
    defaults [:read, update: [:name]]
  end

  policies do
    policy action_type(:read) do
      description "Instance settings are public information"
      authorize_if always()
    end

    policy action_type(:update) do
      description "Only administrators can update instance settings"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      default "Watch Club"
      public? true
      constraints min_length: 3, max_length: 30
    end

    attribute :singleton, :boolean do
      allow_nil? false
      default true
      public? false
    end

    timestamps()
  end

  identities do
    identity :singleton, [:singleton]
  end
end
