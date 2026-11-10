defmodule WatchClubWeb.Storybook.PlayOrRequestButton do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Requests.ContentRequest
  alias WatchClubWeb.Components.Contents.PlayOrRequestButton

  def function, do: &PlayOrRequestButton.play_or_request_button/1

  def template do
    """
    <div class="w-72 p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :play,
        description:
          "Play, Resume, disabled while the next TV Show Episode has no Media, and with every episode, also disabled",
        template: group_template(),
        variations: [
          %Variation{
            id: :play,
            attributes: %{id: "play", has_media?: true, play_href: "#", play_label: "Play"}
          },
          %Variation{
            id: :resume,
            attributes: %{
              id: "resume",
              has_media?: true,
              play_href: "#",
              play_label: "Resume S01E03"
            }
          },
          %Variation{
            id: :nothing_to_play,
            attributes: %{id: "nothing-to-play", has_media?: true, play_label: "Play"}
          },
          %Variation{
            id: :with_episodes,
            attributes: %{
              id: "with-episodes",
              has_media?: true,
              play_href: "#",
              play_label: "Resume S01E03",
              on_episodes: "open_episodes"
            }
          },
          %Variation{
            id: :nothing_to_play_with_episodes,
            attributes: %{
              id: "nothing-to-play-with-episodes",
              has_media?: true,
              play_label: "Play S01E03",
              on_episodes: "open_episodes"
            }
          }
        ]
      },
      %VariationGroup{
        id: :request,
        description:
          "Request, also when somebody else made the Content Request, then how far it got, for one of its Request Subscribers",
        template: group_template(),
        variations: [
          %Variation{
            id: :request,
            attributes: %{id: "request", has_media?: false, play_label: "Play"}
          },
          request_variation(:requested_by_somebody_else, :downloading, false)
          | for(status <- statuses(), do: request_variation(status, status, true))
        ]
      },
      %VariationGroup{
        id: :round,
        description: "Round: Play, disabled Play, Request, then how far it got",
        template: row_template(),
        variations: [
          %Variation{
            id: :play,
            attributes: %{
              id: "round-play",
              variant: "round",
              has_media?: true,
              play_href: "#",
              play_label: "Resume",
              title: "Dune"
            }
          },
          %Variation{
            id: :nothing_to_play,
            attributes: %{
              id: "round-nothing-to-play",
              variant: "round",
              has_media?: true,
              play_label: "Play S01E01",
              title: "Dune"
            }
          },
          %Variation{
            id: :request,
            attributes: %{
              id: "round-request",
              variant: "round",
              has_media?: false,
              play_label: "Play",
              title: "Dune"
            }
          }
          | for(status <- statuses(), do: request_variation(status, status, true, "round"))
        ]
      },
      %VariationGroup{
        id: :poster,
        description: "Over a poster: Play, disabled Play, then how far it got",
        template: row_template(),
        variations: [
          %Variation{
            id: :play,
            attributes: %{
              id: "poster-play",
              variant: "poster",
              has_media?: true,
              play_href: "#",
              play_label: "Resume",
              title: "Dune"
            }
          },
          %Variation{
            id: :nothing_to_play,
            attributes: %{
              id: "poster-nothing-to-play",
              variant: "poster",
              has_media?: true,
              play_label: "Play S01E01",
              title: "Dune"
            }
          },
          request_variation(:downloading, :downloading, true, "poster"),
          request_variation(:failed, :failed, true, "poster")
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        template: group_template(),
        variations:
          for size <- ~w(sm md lg) do
            %Variation{
              id: String.to_atom(size),
              attributes: %{
                id: "size-#{size}",
                size: size,
                has_media?: true,
                play_href: "#",
                play_label: "Play"
              }
            }
          end
      }
    ]
  end

  defp group_template do
    """
    <div class="flex w-72 flex-col gap-2 p-4 text-text">
      <.psb-variation-group />
    </div>
    """
  end

  defp row_template do
    """
    <div class="flex flex-wrap items-center gap-2 p-4 text-text">
      <.psb-variation-group />
    </div>
    """
  end

  defp statuses, do: [:searching, :downloading, :importing, :not_released, :not_found, :failed]

  # A Content Request with this status, at 40% while it downloads
  defp request_variation(id, status, actor_subscriber?, variant \\ "button") do
    %Variation{
      id: id,
      attributes: %{
        id: "#{variant}-request-#{id}",
        variant: variant,
        has_media?: false,
        play_label: "Play",
        title: "Dune",
        locale: :en_US,
        release_date: ~D[2099-03-12],
        request: %ContentRequest{
          status: status,
          actor_subscriber?: actor_subscriber?,
          download_progress: %{downloading: 40.0, importing: 100.0}[status]
        }
      }
    }
  end
end
