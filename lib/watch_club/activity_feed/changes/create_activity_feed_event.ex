defmodule WatchClub.ActivityFeed.Changes.CreateActivityFeedEvent do
  @moduledoc """
  A generic Ash Change that creates the appropriate Activity Feed event depending on the action
  being executed.
  It will crash if called on an action that does not have a related activity feed event
  """
  use Ash.Resource.Change

  alias WatchClub.ActivityFeed.Event

  alias WatchClub.Clubs.{Club, Library, LibraryItem, Membership}

  @impl true
  def change(%Ash.Changeset{action_type: :create, data: %Club{}} = changeset, _opts, context) do
    create_event_after_action!(
      changeset,
      :create_club_created,
      fn club -> %{club_id: club.id, club_created: %{club_id: club.id}} end,
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
          :create_member_added,
          fn membership ->
            %{club_id: membership.club_id, member_added: %{membership_id: membership.id}}
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
      :create_library_created,
      fn library -> %{club_id: library.club_id, library_created: %{library_id: library.id}} end,
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
      :create_content_added,
      fn %LibraryItem{} = library_item ->
        %{
          club_id: library_item.library.club_id,
          content_id: library_item.content_id,
          content_added: %{library_item_id: library_item.id}
        }
      end,
      context,
      load: [:library]
    )
  end

  defp create_event_after_action!(changeset, action, params, context, opts \\ nil) do
    Ash.Changeset.after_action(changeset, fn _changeset, resource ->
      resource =
        if opts[:load] do
          Ash.load!(resource, opts[:load], authorize?: false)
        else
          resource
        end

      {_event, notifications} =
        Event
        |> Ash.create!(
          params.(resource),
          action: action,
          actor: context.actor,
          authorize?: false,
          return_notifications?: true
        )

      {:ok, resource, notifications}
    end)
  end
end
