defmodule WatchClub.Contents.Changes.UpdateShowEpisodes do
  @moduledoc """
  A change that bulk updates one or several TV show episode.
  The update action to call must be passed as an :action parameter
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Contents.TvShowEpisode

  @impl true
  def init(opts) do
    case Keyword.get(opts, :action) do
      nil -> {:error, ":action must be specified"}
      action when action in [:mark_watched, :mark_not_watched] -> {:ok, opts}
      _ -> {:error, ":action must be a valid TvShowEpisode action"}
    end
  end

  @impl true
  def change(changeset, opts, context) do
    action = Keyword.fetch!(opts, :action)

    Ash.Changeset.after_action(changeset, fn _changeset, tv_show ->
      tv_show_id = tv_show.id
      season_number = Ash.Changeset.get_argument(changeset, :season_number)
      episode_number = Ash.Changeset.get_argument(changeset, :episode_number)

      TvShowEpisode
      |> Ash.Query.filter(tv_show_id == ^tv_show_id)
      |> Ash.Query.filter(is_nil(^season_number) or season_number == ^season_number)
      |> Ash.Query.filter(is_nil(^episode_number) or episode_number == ^episode_number)
      |> Ash.bulk_update!(action, %{}, scope: context, strategy: :stream)

      {:ok, tv_show}
    end)
  end
end
