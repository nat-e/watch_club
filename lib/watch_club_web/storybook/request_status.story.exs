defmodule WatchClubWeb.Storybook.RequestStatus do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Requests.ContentRequest
  alias WatchClubWeb.Components.Requests.RequestStatus

  def function, do: &RequestStatus.request_status/1

  def template do
    """
    <div class="flex w-80 flex-col gap-4 p-4 text-text">
      <.psb-variation-group />
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :statuses,
        description:
          "Every Content Request Status, the TV Show Episodes with Media while it downloads or imports, and Completed once its Media was deleted",
        variations: [
          variation(:searching, %ContentRequest{status: :searching}),
          variation(:downloading, %ContentRequest{status: :downloading, download_progress: 40.0}),
          variation(:episodes_ready, %ContentRequest{
            status: :downloading,
            download_progress: 47.0,
            aired_episodes_count: 10,
            aired_episodes_with_media_count: 4
          }),
          variation(:importing, %ContentRequest{status: :importing, download_progress: 100.0}),
          variation(:out_on, %ContentRequest{status: :not_released}, ~D[2099-03-12]),
          variation(:not_released, %ContentRequest{status: :not_released}),
          variation(:not_found, %ContentRequest{status: :not_found}),
          variation(:failed, %ContentRequest{status: :failed}),
          variation(:completed, %ContentRequest{status: :completed})
        ]
      }
    ]
  end

  defp variation(id, request, release_date \\ nil) do
    %Variation{
      id: id,
      attributes: %{
        request: request,
        release_date: release_date,
        locale: :en_US,
        administrator: %User{username: "nate"}
      }
    }
  end
end
