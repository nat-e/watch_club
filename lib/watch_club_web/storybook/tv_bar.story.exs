defmodule WatchClubWeb.Storybook.TvBar do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.{User, UserSettings}
  alias WatchClub.Contents.{TvShow, TvShowEpisode, TvShowEpisodeLocalization, TvShowLocalization}
  alias WatchClub.MediaCatalog.{Media, Part, Video}
  alias WatchClub.Playbacks.{Playback, Session}
  alias WatchClubWeb.Components.Playbacks.TvBar

  def function, do: &TvBar.tv_bar/1

  # The bar docks at the bottom of the window: the frame keeps it in view, as wide as a phone
  def template do
    """
    <div class="relative h-24 w-96 max-w-full overflow-hidden [transform:translateZ(0)] [--wc-tab-bar-height:0px] [--wc-sidebar-width:0px] [--wc-tv-bar-height:4.25rem]">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :playing,
        description: "Playing and paused",
        variations: [
          %Variation{
            id: :playing,
            attributes: %{id: "tv-bar-playing", session: session(false), current_user: user()}
          },
          %Variation{
            id: :paused,
            attributes: %{id: "tv-bar-paused", session: session(true), current_user: user()}
          },
          %Variation{
            id: :part,
            description: "Playing Part 2 of an episode in two files",
            attributes: %{id: "tv-bar-part", session: session(false, 2), current_user: user()}
          }
        ]
      }
    ]
  end

  # A Playback Session on a TV, playing Part `part_number` of an episode in that many files
  def session(paused?, part_number \\ 1) do
    parts = for number <- 1..part_number, do: %Part{number: number, movie: nil, sports_event: nil}

    episode = %TvShowEpisode{
      id: Ash.UUIDv7.generate(),
      formatted_episode_number: "S02E03",
      still_path: "/j4AUAq1XJOBmfXsLphZzsCz6pZs.jpg",
      best_localization: %TvShowEpisodeLocalization{title: "Who Is Alive?"},
      parts: parts,
      tv_show: %TvShow{
        best_localization: %TvShowLocalization{title: "Severance"},
        backdrop_path: "/ixgFmf1X59PUZam2qbAfskx2gQr.jpg"
      }
    }

    %Session{
      tv_name: "Living Room TV",
      paused?: paused?,
      position_seconds: 1234.0,
      last_heartbeat_at: DateTime.utc_now(),
      current_playback: %Playback{
        media: %Media{
          video: %Video{
            duration_seconds: 2940.0,
            parts: [%{List.last(parts) | tv_show_episode: episode}]
          }
        }
      }
    }
  end

  defp user, do: %User{username: "nate", settings: %UserSettings{locale: :en_US}}
end
