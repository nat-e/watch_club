defmodule WatchClubWeb.Storybook.PlayOrRequestButton do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequest}
  alias WatchClubWeb.Components.Contents.PlayOrRequestButton

  def function, do: &PlayOrRequestButton.play_or_request_button/1

  def template do
    """
    <div class="w-56 p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :play,
        description:
          "Play, Resume, nothing to play yet, and with every episode, also when there's nothing to play",
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
          "Request, then the Content Request's status, for one of its Request Subscribers",
        template: group_template(),
        variations: [
          %Variation{
            id: :request,
            attributes: %{id: "request", has_media?: false, play_label: "Play"}
          },
          request_variation(:queued, :queued, true),
          request_variation(:downloading, :downloading, true),
          request_variation(:importing, :importing, true),
          request_variation(:not_released, :not_released, true),
          request_variation(:not_found, :not_found, true),
          request_variation(:failed, :failed, true)
        ]
      },
      %VariationGroup{
        id: :get_notified,
        description:
          "Get Notified, for the other Users, with who made the Content Request in the status' tooltip: lea, or a deleted User",
        template: group_template(),
        variations: [
          request_variation(:requested_by_user, :downloading, false),
          request_variation(:requested_by_deleted_user, :queued, false, nil)
        ]
      },
      %Variation{
        id: :round,
        description: "Round, over a poster",
        attributes: %{
          id: "round",
          variant: "round",
          has_media?: true,
          play_href: "#",
          play_label: "Resume",
          title: "Dune"
        }
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
    <div class="flex w-56 flex-col gap-2 p-4 text-text">
      <.psb-variation-group />
    </div>
    """
  end

  # A Content Request with this status, at 40% while it downloads
  defp request_variation(id, status, actor_subscriber?, requested_by \\ %User{username: "lea"}) do
    %Variation{
      id: id,
      attributes: %{
        id: "request-#{id}",
        has_media?: false,
        play_label: "Play",
        request: %ContentRequest{
          status: status,
          actor_subscriber?: actor_subscriber?,
          requested_by: requested_by,
          best_source_request: %MediaSourceRequest{
            download_progress: if(status == :importing, do: 100.0, else: 40.0)
          }
        }
      }
    }
  end
end
