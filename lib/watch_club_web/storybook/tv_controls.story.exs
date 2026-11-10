defmodule WatchClubWeb.Storybook.TvControls do
  use PhoenixStorybook.Story, :live_component

  alias WatchClub.Accounts.{User, UserSettings}
  alias WatchClubWeb.Components.Playbacks.TvControlsLive
  alias WatchClubWeb.Storybook.TvBar

  def component, do: TvControlsLive

  def template do
    """
    <div class="@container w-96 p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :remote,
        description: "The Remote's, while the TV plays",
        attributes: %{session: TvBar.session(false), current_user: user(), layout: "remote"}
      },
      %Variation{
        id: :remote_paused,
        description: "The Remote's, while the TV is paused",
        attributes: %{session: TvBar.session(true), current_user: user(), layout: "remote"}
      }
    ]
  end

  defp user, do: %User{username: "nate", settings: %UserSettings{locale: :en_US}}
end
