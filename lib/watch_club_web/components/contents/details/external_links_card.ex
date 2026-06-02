defmodule WatchClubWeb.Components.Contents.Details.ExternalLinksCard do
  @moduledoc """
  External links card shared by the Movie and TV Show detail pages.
  """
  use WatchClubWeb, :component

  alias WatchClub.Contents.ContentView
  alias WatchClub.Integrations.Tmdb.{MovieDetailsResponse, TvDetailsResponse}

  attr :content, ContentView, required: true

  def external_links_card(assigns) do
    ~H"""
    <.section
      :if={external_links(@content.details) != []}
      title={dgettext("contents", "External links")}
      icon={:external_link}
    >
      <ul class="grid gap-related">
        <li :for={link <- external_links(@content.details)}>
          <.external_link_button link={link} />
        </li>
      </ul>
    </.section>
    """
  end

  attr :link, :map, required: true

  defp external_link_button(assigns) do
    ~H"""
    <.button
      id={"details-link-#{@link.id}"}
      href={@link.url}
      target="_blank"
      variant="secondary"
      class="w-full justify-between"
    >
      {@link.label}
      <:icon position="end"><Lucideicons.external_link /></:icon>
    </.button>
    """
  end

  defp external_links(%MovieDetailsResponse{} = details) do
    [
      details.imdb_id &&
        %{
          id: "imdb",
          label: "IMDb",
          url: "https://www.imdb.com/title/#{details.imdb_id}"
        },
      %{
        id: "tmdb",
        label: "TMDB",
        url: "https://www.themoviedb.org/movie/#{details.id}"
      },
      present_url(details.homepage) &&
        %{
          id: "official-site",
          label: dgettext("contents", "Official site"),
          url: details.homepage
        },
      %{
        id: "letterboxd-search",
        label: dgettext("contents", "Letterboxd search"),
        url: "https://letterboxd.com/search/#{URI.encode_www_form(details.title || "")}/"
      }
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp external_links(%TvDetailsResponse{} = details) do
    [
      details.external_ids.imdb_id &&
        %{
          id: "imdb",
          label: "IMDb",
          url: "https://www.imdb.com/title/#{details.external_ids.imdb_id}"
        },
      %{
        id: "tmdb",
        label: "TMDB",
        url: "https://www.themoviedb.org/tv/#{details.id}"
      },
      present_url(details.homepage) &&
        %{
          id: "official-site",
          label: dgettext("contents", "Official site"),
          url: details.homepage
        }
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp present_url(nil), do: nil
  defp present_url(""), do: nil
  defp present_url(url), do: url
end
