defmodule WatchClubWeb.Storybook.PartName do
  use PhoenixStorybook.Story, :component

  alias WatchClub.MediaCatalog.Part
  alias WatchClubWeb.Components.Medias.PartName

  def function, do: &PartName.part_name/1

  def variations do
    [
      %Variation{
        id: :numbered,
        description: "A Part without a name, such as the second half of a two-part episode",
        attributes: %{part: %Part{number: 2}}
      },
      %Variation{
        id: :named,
        description: "A Part its source names, such as a fight card's Main Card",
        attributes: %{part: %Part{number: 3, name: "Main Card"}}
      }
    ]
  end
end
