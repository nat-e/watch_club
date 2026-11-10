defmodule WatchClubWeb.Storybook.SearchResultSummary do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Contents.{ContentIdentity, SearchResult}
  alias WatchClubWeb.Components.Search.SearchResultRow

  def function, do: &SearchResultRow.search_result_summary/1

  # A row of the app bar's search
  def template do
    """
    <div class="flex w-[32rem] items-center gap-group p-related text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :in_library,
        description: "Its type, year and whether it's in the Library",
        attributes: %{result: dune(has_media?: true)}
      },
      %Variation{
        id: :without_type,
        description: "Without its type, when the search has only one",
        attributes: %{result: dune(), type: false}
      },
      %Variation{
        id: :overview,
        description: "With its overview, as on the Search page",
        attributes: %{result: dune(), overview: true}
      },
      %Variation{
        id: :other_facts,
        description: "Other facts instead, such as a Media's episode",
        attributes: %{result: severance()},
        slots: [
          """
          <:facts>
            <.badge variant="secondary" size="sm">S02E05</.badge>
          </:facts>
          """
        ]
      }
    ]
  end

  defp dune(fields \\ []) do
    struct!(
      %SearchResult{
        identity: ContentIdentity.for_movie(438_631),
        title: "Dune",
        year: 2021,
        overview: "Paul Atreides travels to the most dangerous planet in the universe.",
        poster_path: "/v1tRXZ4JtD2Iv6fjkPvT4GiwslV.jpg"
      },
      fields
    )
  end

  defp severance do
    %SearchResult{
      identity: ContentIdentity.for_tv_show(95_396),
      title: "Severance",
      year: 2022,
      poster_path: "/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg"
    }
  end
end
