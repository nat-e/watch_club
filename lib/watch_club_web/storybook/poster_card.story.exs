defmodule WatchClubWeb.Storybook.PosterCard do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Contents.{Content, Movie, MovieLocalization}
  alias WatchClubWeb.Components.Contents.{PlayOrRequestButton, PosterCard}

  def function, do: &PosterCard.poster_card/1

  def imports, do: [{PlayOrRequestButton, [play_or_request_button: 1]}]

  def template do
    """
    <div class="w-36 p-4 text-text">
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      variation(:not_watched, "Not watched", :not_started, false),
      variation(:in_progress, "In progress", :in_progress, false),
      variation(:watched, "Watched", :completed, false),
      variation(
        :ready_unseen,
        "Ready unseen, on My Requests: ringed, with a New badge instead of its progress",
        :in_progress,
        true
      )
    ]
  end

  defp variation(id, description, progress_status, ready_unseen) do
    %Variation{
      id: id,
      description: description,
      attributes: %{
        content: content(progress_status),
        locale: :en_US,
        ready_unseen: ready_unseen
      },
      slots: [
        """
        <:action>
          <.play_or_request_button
            id="play-#{id}"
            variant="round"
            has_media?={true}
            play_href="#"
            play_label="Play"
            title="Dune"
          />
        </:action>
        """
      ]
    }
  end

  defp content(progress_status) do
    %Content{
      id: "dune",
      type: :movie,
      external_id_source: :tmdb,
      external_id: "438631",
      rating: 7.8,
      original_language: "en",
      release_date: ~D[2021-09-15],
      actor_progress_status: progress_status,
      implementation: %Movie{
        best_localization: %MovieLocalization{
          title: "Dune",
          poster_path: "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg"
        }
      }
    }
  end
end
