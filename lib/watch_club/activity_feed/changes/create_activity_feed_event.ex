defmodule WatchClub.ActivityFeed.Changes.CreateActivityFeedEvent do
  @moduledoc """
  A generic Ash Change that creates the appropriate Activity Feed event depending on the action
  being executed. Each event manages its own fan-out scopes.
  It will crash if called on an action that does not have a related activity feed event.
  """
  use Ash.Resource.Change

  alias WatchClub.ActivityFeed.Events.{
    ClubCreatedEvent,
    ContentAddedEvent,
    LibraryCreatedEvent,
    MemberAddedEvent
  }

  alias WatchClub.Clubs.{Club, Library, LibraryItem, Membership}

  @impl true
  def change(%Ash.Changeset{action_type: :create, data: %Club{}} = changeset, _opts, context) do
    create_event_after_action!(
      changeset,
      ClubCreatedEvent,
      fn club ->
        %{club_id: club.id, scopes: club_event_scope(club.id)}
      end,
      context
    )
  end

  def change(
        %Ash.Changeset{action_type: :create, data: %Membership{}} = changeset,
        _opts,
        context
      ) do
    # We don't create a membership created event for the owner, it's redundant
    case Ash.Changeset.get_attribute(changeset, :role) do
      :member ->
        create_event_after_action!(
          changeset,
          MemberAddedEvent,
          fn membership ->
            %{
              membership_id: membership.id,
              scopes: club_event_scope(membership.club_id)
            }
          end,
          context
        )

      _ ->
        changeset
    end
  end

  def change(%Ash.Changeset{action_type: :create, data: %Library{}} = changeset, _opts, context) do
    create_event_after_action!(
      changeset,
      LibraryCreatedEvent,
      fn library ->
        %{
          library_id: library.id,
          scopes: club_event_scope(library.club_id)
        }
      end,
      context
    )
  end

  def change(
        %Ash.Changeset{action_type: :create, data: %LibraryItem{}} = changeset,
        _opts,
        context
      ) do
    create_event_after_action!(
      changeset,
      ContentAddedEvent,
      fn %LibraryItem{} = library_item ->
        %{
          library_item_id: library_item.id,
          scopes:
            club_event_scope(
              library_item.library.club_id,
              library_item.content_id
            )
        }
      end,
      context,
      load: [:library]
    )
  end

  defp create_event_after_action!(changeset, resource, params, context, opts \\ nil) do
    Ash.Changeset.after_action(changeset, fn _changeset, record ->
      record =
        if opts[:load] do
          Ash.load!(record, opts[:load], authorize?: false)
        else
          record
        end

      # Ash can't send notifications from inside the outer action's transaction.
      # `return_notifications?: true` hands them back, and returning them from
      # this hook makes the outer action send them after it commits. Dropping
      # them skips the broadcast without any warning.
      {_event, notifications} =
        resource
        |> Ash.create!(
          params.(record),
          action: :create,
          actor: context.actor,
          authorize?: false,
          return_notifications?: true
        )

      {:ok, record, notifications}
    end)
  end

  def club_event_scope(club_id, content_id \\ nil) do
    [%{scope_club_id: club_id, content_id: content_id}]
  end
end
