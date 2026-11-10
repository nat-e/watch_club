defmodule WatchClub.Requests.Changes.MarkSubscribersReadyUnseen do
  @moduledoc """
  After its Content Request is updated, makes each of its Request Subscribers ready unseen.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias WatchClub.Requests.RequestSubscriber

  @impl true
  def change(changeset, _opts, context), do: mark_after_action(changeset, context)

  @impl true
  def atomic(changeset, _opts, context), do: {:ok, mark_after_action(changeset, context)}

  defp mark_after_action(changeset, context) do
    Ash.Changeset.after_action(changeset, fn _changeset, request ->
      RequestSubscriber
      |> Ash.Query.filter(content_request_id == ^request.id)
      |> Ash.bulk_update!(:mark_ready_unseen, %{}, Ash.Context.to_opts(context, notify?: true))

      {:ok, request}
    end)
  end
end
