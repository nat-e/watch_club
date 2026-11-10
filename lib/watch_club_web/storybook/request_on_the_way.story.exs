defmodule WatchClubWeb.Storybook.RequestOnTheWay do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.{User, UserSettings}
  alias WatchClub.Contents.{Content, Movie, MovieLocalization}
  alias WatchClub.Requests.ContentRequest
  alias WatchClubWeb.MyRequestsPage.RequestOnTheWay

  def function, do: &RequestOnTheWay.request_on_the_way/1

  def template do
    """
    <ul class="w-[28rem] max-w-full p-4 text-text">
      <.psb-variation/>
    </ul>
    """
  end

  def variations do
    [
      variation(:importing, "Downloaded, being imported", :importing),
      variation(:downloading, "Downloading, with how far it got", :downloading,
        download_progress: 64.0
      ),
      variation(
        :episodes_ready,
        "Downloading, with TV Show Episodes in the Library, but not the next one: no Play",
        :downloading,
        download_progress: 47.0,
        aired_episodes_count: 10,
        aired_episodes_with_media_count: 4,
        title: "Silo"
      ),
      variation(
        :searching,
        "Searched for by a Media Source, or waiting for the Instance Administrator",
        :searching
      ),
      variation(:out_later, "Not released, out on a later date", :not_released,
        release_date: Date.add(Date.utc_today(), 40)
      ),
      variation(:not_released, "Not released, with a date that has passed", :not_released),
      variation(:not_found, "Not found yet", :not_found),
      variation(:failed, "Needs the Instance Administrator", :failed),
      variation(:long_name, "A long name, on two lines at most", :searching,
        title: "Strikeforce / M-1 Global - Fedor vs. Werdum, the full card from San Jose"
      )
    ]
  end

  defp variation(id, description, status, opts \\ []) do
    %Variation{
      id: id,
      description: description,
      attributes: %{
        request: %ContentRequest{
          id: "request-#{id}",
          status: status,
          download_progress: opts[:download_progress],
          aired_episodes_count: opts[:aired_episodes_count],
          aired_episodes_with_media_count: opts[:aired_episodes_with_media_count],
          content: %Content{
            type: :movie,
            actor_ready_to_play?: false,
            external_id_source: :tmdb,
            external_id: "438631",
            release_date: opts[:release_date] || ~D[2021-09-15],
            implementation: %Movie{
              best_localization: %MovieLocalization{
                title: opts[:title] || "Dune",
                poster_path: "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg"
              }
            }
          }
        },
        focus_after_removal: "requests-on-the-way-heading",
        current_user: %User{settings: %UserSettings{locale: :en_US}}
      }
    }
  end
end
