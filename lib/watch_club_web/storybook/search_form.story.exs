defmodule WatchClubWeb.Storybook.SearchForm do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Search.SearchForm

  def function, do: &SearchForm.search_form/1

  # At the top of a dialog
  def template do
    """
    <div class="w-full max-w-md rounded-card bg-surface-overlay p-cluster text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :empty,
        description: "Before typing, with its label as the placeholder",
        attributes: %{id: "search-empty", query: "", label: "Search", on_search: "search"}
      },
      %Variation{
        id: :placeholder,
        description: "A placeholder that says what to type, as in Match",
        attributes: %{
          id: "search-placeholder",
          query: "",
          label: "Search TMDB",
          placeholder: "Movie title or TMDB ID",
          on_search: "search"
        }
      },
      %Variation{
        id: :query,
        description: "With a query, and the clear button Chrome and Safari add",
        attributes: %{id: "search-query", query: "Dune", label: "Search", on_search: "search"}
      }
    ]
  end
end
