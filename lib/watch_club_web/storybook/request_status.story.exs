defmodule WatchClubWeb.Storybook.RequestStatus do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Requests.RequestStatus

  def function, do: &RequestStatus.request_status/1

  def template do
    """
    <div class="p-4 text-text">
      <.psb-variation-group />
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :statuses,
        description: "Every Content Request Status, in the color of how it's going",
        variations:
          for status <- WatchClub.Requests.ContentRequestStatus.values() do
            %Variation{id: status, attributes: %{status: status}}
          end
      }
    ]
  end
end
