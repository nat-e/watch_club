defmodule WatchClub.History.WatchProgress.Actions.ListWatchers do
  @moduledoc """
  Lists the Users other than the actor who have Watch Progress on a Content, as `Watcher`s, the
  latest first.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias WatchClub.Contents
  alias WatchClub.History.{Watcher, WatchProgress}

  @impl true
  def run(input, _opts, context) do
    %{external_id_source: source, external_id: external_id} = input.arguments.content_identity

    case Contents.get_content_by_external_id!(source, external_id,
           load: [tv_show: [:aired_episodes_count]],
           not_found_error?: false,
           actor: context.actor
         ) do
      nil -> {:ok, []}
      content -> {:ok, watchers!(content, context)}
    end
  end

  defp watchers!(content, context) do
    WatchProgress
    |> Ash.Query.filter(
      user_id != ^context.actor.id and
        (movie_id == ^content.id or tv_show_episode.tv_show_id == ^content.id)
    )
    |> Ash.Query.load([:user, tv_show_episode: [:aired?]])
    |> Ash.read!(Ash.Context.to_opts(context))
    |> Enum.group_by(& &1.user_id)
    |> Enum.map(fn {_user_id, [progress | _] = progresses} ->
      %Watcher{
        user: progress.user,
        status: status(content, progresses),
        last_watched_at: progresses |> Enum.map(& &1.updated_at) |> Enum.max(DateTime)
      }
    end)
    |> Enum.sort_by(& &1.last_watched_at, {:desc, DateTime})
  end

  # The rules of Movie.actor_progress_status and TvShow.actor_progress_status, for another User
  defp status(%{type: :movie}, [%WatchProgress{completed: true}]), do: :completed
  defp status(%{type: :movie}, _progresses), do: :in_progress

  defp status(%{type: :tv_show, tv_show: tv_show}, progresses) do
    finished = Enum.count(progresses, &(&1.completed and &1.tv_show_episode.aired?))
    if finished == tv_show.aired_episodes_count, do: :completed, else: :in_progress
  end
end
