defmodule WatchClubWeb.Storybook.PlaylistLink do
  use PhoenixStorybook.Story, :component

  alias WatchClub.Accounts.User
  alias WatchClub.Playlists.{Playlist, PlaylistAccess}
  alias WatchClubWeb.Components.Playlists.PlaylistLink

  @viewer %User{id: "01a1b100-0000-7000-8000-000000000001", username: "playlistreview"}
  @lea %User{id: "01a1b100-0000-7000-8000-000000000002", username: "leadelpeut"}
  @vinz %User{id: "01a1b100-0000-7000-8000-000000000003", username: "vinz"}

  def function, do: &PlaylistLink.playlist_link/1

  # The layout's main column, wide enough for a split view to show the list beside the Playlist
  def template do
    """
    <div class="@container/main w-[60rem]">
      <div class="w-72 p-4 text-text">
        <.psb-variation/>
      </div>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :private,
        description: "Private: a lock",
        attributes: %{
          playlist: playlist("To Watch", "popcorn", @viewer, [], 2, 1),
          current_user: @viewer,
          patch: "#"
        }
      },
      %Variation{
        id: :shared,
        description: "Shared: who else has it",
        attributes: %{
          playlist: playlist("Watch with Léa", "heart", @viewer, [@lea], 1, 0),
          current_user: @viewer,
          patch: "#"
        }
      },
      %Variation{
        id: :shared_with_you,
        description: "Shared with you: its owner first",
        attributes: %{
          playlist: playlist("Climbing films", "mountain", @vinz, [@viewer, @lea], 0, 3),
          current_user: @viewer,
          patch: "#"
        }
      },
      %Variation{
        id: :shared_unseen,
        description: "Shared with you since you last opened your Playlists",
        attributes: %{
          playlist: playlist("Climbing films", "mountain", @vinz, [@viewer], 0, 3),
          current_user: @viewer,
          patch: "#",
          shared_unseen: true
        }
      },
      %Variation{
        id: :sports_events,
        description: "Holding Sports Events",
        attributes: %{
          playlist: playlist("Fight nights", "trophy", @viewer, [], 1, 0, 2),
          current_user: @viewer,
          patch: "#"
        }
      },
      %Variation{
        id: :empty,
        description: "Empty",
        attributes: %{
          playlist: playlist("French cinema", "film", @viewer, [], 0, 0),
          current_user: @viewer,
          patch: "#"
        }
      },
      %Variation{
        id: :selected,
        description: "The Playlist shown beside the list",
        attributes: %{
          playlist: playlist("To Watch", "popcorn", @viewer, [], 2, 1),
          current_user: @viewer,
          patch: "#",
          selected: true
        }
      }
    ]
  end

  defp playlist(name, icon, owner, users, movie_count, tv_show_count, sports_event_count \\ 0) do
    %Playlist{
      id: name |> String.downcase() |> String.replace(" ", "-"),
      name: name,
      icon: icon,
      owner_id: owner.id,
      owner: owner,
      accesses: Enum.map(users, &%PlaylistAccess{user_id: &1.id, user: &1, level: :view}),
      movie_count: movie_count,
      tv_show_count: tv_show_count,
      sports_event_count: sports_event_count
    }
  end
end
