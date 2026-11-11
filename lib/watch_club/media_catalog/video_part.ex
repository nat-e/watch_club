defmodule WatchClub.MediaCatalog.VideoPart do
  @moduledoc "A Video contains a Part. Written through the Video's `parts`."
  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.MediaCatalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias WatchClub.MediaCatalog.{Part, Video}

  postgres do
    table "video_parts"
    repo WatchClub.Repo

    references do
      # The primary key starts with video_id
      reference :video, on_delete: :delete
      reference :part, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read, :destroy, create: []]
  end

  policies do
    policy actor_absent() do
      description "Video Part actions require an authenticated actor"
      access_type :strict
      forbid_if always()
    end

    policy action_type(:read) do
      description "Any authenticated actor can read Video Parts"
      authorize_if always()
    end

    policy action_type([:create, :destroy]) do
      description "Only the system actor can write Video Parts"
      authorize_if actor_attribute_equals(:system?, true)
    end
  end

  relationships do
    belongs_to :video, Video do
      primary_key? true
      allow_nil? false
    end

    belongs_to :part, Part do
      primary_key? true
      allow_nil? false
    end
  end
end
