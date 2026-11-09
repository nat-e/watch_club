defmodule WatchClubWeb.Storybook.MediaTypeIcon do
  use PhoenixStorybook.Story, :component

  alias WatchClub.MediaCatalog.MediaType
  alias WatchClubWeb.Components.Media.MediaTypeBadge

  def function, do: &MediaTypeBadge.media_type_icon/1

  def template do
    """
    <div class="p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    for media_type <- MediaType.values() do
      %Variation{
        id: media_type,
        description: MediaType.translated_label(media_type),
        attributes: %{media_type: media_type, class: "size-icon"}
      }
    end
  end
end
