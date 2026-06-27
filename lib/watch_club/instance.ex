defmodule WatchClub.Instance do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.Instance.InstanceSettings

  resources do
    resource InstanceSettings do
      define :get_instance_settings, action: :read, get?: true
      define :update_instance_settings, action: :update
    end
  end
end
