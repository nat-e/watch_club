defmodule WatchClubWeb.Storybook.PlayOrRequestButton do
  use PhoenixStorybook.Story, :component

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
        description: "Play, Resume, and nothing to play yet",
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
          }
        ]
      },
      %VariationGroup{
        id: :request,
        description: "Request, then the state of the Content Request",
        template: group_template(),
        variations: [
          %Variation{
            id: :request,
            attributes: %{id: "request", has_media?: false, play_label: "Play"}
          },
          request_variation(:queued, nil),
          request_variation(:searching, :searching),
          request_variation(:downloading, :downloading),
          request_variation(:not_released, :not_released),
          request_variation(:needs_attention, :needs_attention)
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

  # A Content Request whose best Media Source Request has this status, or has none yet
  defp request_variation(id, status) do
    %Variation{
      id: id,
      attributes: %{
        id: "request-#{id}",
        has_media?: false,
        play_label: "Play",
        request: %ContentRequest{
          best_source_request: status && %MediaSourceRequest{status: status}
        }
      }
    }
  end
end
