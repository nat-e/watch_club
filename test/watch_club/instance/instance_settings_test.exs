defmodule WatchClub.Instance.InstanceSettingsTest do
  use WatchClub.DataCase

  import WatchClub.Instance

  alias WatchClub.Instance.InstanceSettings

  describe "update_instance_settings/*" do
    test "an administrator can rename the instance" do
      admin = generate(administrator())
      settings = get_instance_settings!(authorize?: false)

      assert %InstanceSettings{name: "My Cinema"} =
               update_instance_settings!(settings, %{name: "My Cinema"}, actor: admin)
    end

    test "rejects non-admin actors" do
      user = generate(user())
      settings = get_instance_settings!(authorize?: false)

      update_instance_settings(settings, %{name: "My Cinema"}, actor: user)
      |> assert_has_error(Ash.Error.Forbidden, fn _ -> true end)
    end
  end
end
