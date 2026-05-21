defmodule WatchClub.Clubs.Checks.ActorHasAccessToMediaViaLibrary do
  @moduledoc """
  A simple check that validates whether the actor has visibility of the Content
  attached to a Media, through a Library Item in a Club where the actor is a
  Member. For Media attached to a TV Show Episode, visibility is checked
  against the parent TV Show, per CONTEXT.md.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.LibraryItem

  @impl true
  def describe(_options),
    do: "actor has access to the media's content through a library item"

  @impl true
  def match?(%User{} = actor, %{changeset: %Ash.Changeset{} = changeset}, _options) do
    case Ash.Changeset.get_argument_or_attribute(changeset, :media_id) do
      nil ->
        false

      media_id ->
        LibraryItem
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(exists(library.club.memberships, user_id == ^actor.id))
        |> Ash.Query.filter(
          exists(content.movie.videos, id == ^media_id) or
            exists(content.tv_show.episodes.videos, id == ^media_id)
        )
        |> Ash.exists?()
    end
  end

  def match?(_, _, _), do: false
end
