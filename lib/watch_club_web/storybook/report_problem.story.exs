defmodule WatchClubWeb.Storybook.ReportProblem do
  use PhoenixStorybook.Story, :live_component

  alias Phoenix.LiveView.JS
  alias WatchClub.Accounts.{User, UserSettings}
  alias WatchClubWeb.Components.Playbacks.ReportProblemLive

  def component, do: ReportProblemLive

  def variations do
    [
      %Variation{
        id: :default,
        description: "Over the Player or the Remote, with nothing picked yet",
        attributes: attributes(nil)
      },
      %Variation{
        id: :failed,
        description: "Over a Video that failed to play",
        attributes: attributes(:player)
      }
    ]
  end

  defp attributes(category) do
    %{
      details: %{
        "playback_id" => Ash.UUIDv7.generate(),
        "position_seconds" => 1234.0,
        "audio" => "English",
        "quality" => "Auto",
        "user_agent" => "Mozilla/5.0 (X11; Linux aarch64) CrKey/1.56.500000"
      },
      category: category,
      current_user: %User{username: "nate", settings: %UserSettings{locale: :en_US}},
      administrator: %User{username: "admin"},
      on_close: %JS{}
    }
  end
end
