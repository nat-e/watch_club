defmodule WatchClubWeb.Storybook.PosterCard do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Contents.{Content, Movie, MovieLocalization, TvShow, TvShowLocalization}
  alias WatchClub.Conversations.Conversation
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
      variation(:not_watched, "Not watched", :not_started, false, []),
      variation(:in_progress, "In progress", :in_progress, false, []),
      variation(:watched, "Watched", :completed, false, []),
      variation(:recommended, "Recommended by two Users", :not_started, false, ["lea", "vinz"]),
      variation(
        :ready_unseen,
        "Ready unseen, on My Requests: ringed, with a New badge instead of its progress",
        :in_progress,
        true,
        []
      ),
      %Variation{
        id: :incomplete,
        description: "An Incomplete TV Show in progress: an aired TV Show Episode has no Media",
        attributes: %{content: incomplete_tv_show(), locale: :en_US},
        slots: [play_slot(:incomplete)]
      }
    ]
  end

  defp variation(id, description, progress_status, ready_unseen, recommenders) do
    %Variation{
      id: id,
      description: description,
      attributes: %{
        content: content(id, progress_status, recommenders),
        locale: :en_US,
        ready_unseen: ready_unseen
      },
      slots: [play_slot(id)]
    }
  end

  defp play_slot(id) do
    """
    <:action>
      <.play_or_request_button
        id="play-#{id}"
        variant="poster"
        has_media?={true}
        play_href="#"
        play_label="Play"
        title="Dune"
      />
    </:action>
    """
  end

  # Each its own id, so the badges' ids don't repeat on the page
  defp content(id, progress_status, recommenders) do
    %Content{
      id: "dune-#{id}",
      type: :movie,
      incomplete?: false,
      external_id_source: :tmdb,
      external_id: "438631",
      rating: 7.8,
      original_language: "en",
      release_date: ~D[2021-09-15],
      actor_progress_status: progress_status,
      actor_recommendations:
        for username <- recommenders do
          %Conversation{recommended_by: %User{id: username, username: username}}
        end,
      implementation: %Movie{
        best_localization: %MovieLocalization{
          title: "Dune",
          poster_path: "/d5NXSklXo0qyIYkgV94XAgMIckC.jpg"
        }
      }
    }
  end

  defp incomplete_tv_show do
    %Content{
      id: "silo",
      type: :tv_show,
      incomplete?: true,
      external_id_source: :tmdb,
      external_id: "125988",
      rating: 8.1,
      original_language: "en",
      release_date: ~D[2023-05-04],
      actor_progress_status: :in_progress,
      actor_recommendations: [],
      implementation: %TvShow{
        best_localization: %TvShowLocalization{
          title: "Silo",
          poster_path: "/r2QXomqKjkKHVtYGGtkf2l2Y7go.jpg"
        }
      }
    }
  end
end
