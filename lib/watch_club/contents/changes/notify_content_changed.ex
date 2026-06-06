defmodule WatchClub.Contents.Changes.NotifyContentChanged do
  @moduledoc """
  Sends a PubSub notification after an action that changes a Content.

  :content A key or path (list of keys) for resolving the content from the Resource being changed (e.g. :content or [:tv_show, :content]).
  If the :content resolves to a nil record, the notification is not broadcasted

  :user An optional key or path (list of keys) for resolving the User. When set, the notification will be published to the ContentView PubSub topic and only the
  actor will be notified. When false, the notification is sent to a global Content topic (use for changes that are not specific to a given user)
  The `:__actor` atom can be used to resolve the user to the action actor.

  We cannot use the built-in Ash.Notifier.PubSub because it doesn't support the actor id as part of the key
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    content = opts[:content]

    case content do
      nil ->
        {:error, ":content must be provided"}

      content when is_atom(content) or is_list(content) ->
        {:ok, opts}

      _ ->
        {:error, ":content must be a key or path (list of keys) to the content"}
    end
  end

  @impl true
  def change(changeset, opts, context) do
    changeset
    |> snapshot_content_before_destroy(opts, context)
    |> Ash.Changeset.after_transaction(fn
      changeset, {:ok, record} = result ->
        {content, user_id} =
          case changeset.context[:notify_content_changed] do
            nil ->
              content = resolve_content(opts, record)
              {content, content && resolve_user_id(opts, record, context)}

            snapshot ->
              {snapshot.content, snapshot.user_id}
          end

        case content do
          nil ->
            result

          content ->
            notification =
              Ash.Notifier.Notification.new(changeset.resource,
                action: changeset.action,
                data: record,
                actor: context.actor,
                metadata: %{
                  subject: :content_changed,
                  content_id: content.id,
                  external_id_source: content.external_id_source,
                  external_id: content.external_id
                }
              )

            Phoenix.PubSub.broadcast(
              WatchClub.PubSub,
              topic(content, user_id),
              notification
            )

            result
        end

      _changeset, result ->
        # Don't notify when the action fails
        result
    end)
  end

  # A destroy cascades away the rows the content path traverses, so by the time the
  # after_transaction broadcast runs the content is unreachable. Resolve and stash it
  # (with the user to notify) in a before_action, while the rows still exist.
  defp snapshot_content_before_destroy(changeset, opts, context) do
    if changeset.action_type == :destroy do
      Ash.Changeset.before_action(changeset, fn changeset ->
        content = resolve_content(opts, changeset.data)
        user_id = content && resolve_user_id(opts, changeset.data, context)

        Ash.Changeset.put_context(changeset, :notify_content_changed, %{
          content: content,
          user_id: user_id
        })
      end)
    else
      changeset
    end
  end

  defp topic(content, nil),
    do:
      WatchClub.PubSub.content_topic(
        content.external_id_source,
        content.external_id
      )

  defp topic(content, user_id),
    do:
      WatchClub.PubSub.content_view_topic(
        content.external_id_source,
        content.external_id,
        user_id
      )

  defp resolve_content(opts, record) do
    path = opts |> Keyword.fetch!(:content) |> List.wrap()
    resolve_path(record, path)
  end

  defp resolve_user_id(opts, record, context) do
    case Keyword.get(opts, :user) do
      nil ->
        nil

      :__actor ->
        context.actor.id

      path ->
        resolve_path(record, List.wrap(path)).id
    end
  end

  defp resolve_path(record, path) do
    record = load_path(record, path)

    Enum.reduce_while(path, record, fn key, acc ->
      case Map.get(acc, key) do
        nil -> {:halt, nil}
        value -> {:cont, value}
      end
    end)
  end

  defp load_path(record, path) do
    # path is a flat traversal path; nest it into a load statement
    # so Ash loads down the chain, e.g. [:video, :content] -> [video: :content]
    load_statement =
      path
      |> List.wrap()
      |> Enum.reverse()
      |> Enum.reduce(fn key, nested -> [{key, nested}] end)

    Ash.load!(record, load_statement, authorize?: false)
  end
end
