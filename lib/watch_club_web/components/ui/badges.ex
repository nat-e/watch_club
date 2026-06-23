defmodule WatchClubWeb.Components.UI.Badges do
  @moduledoc """
  A collection of Badges and similar inline components for displaying a Resource in a
  standardized manner
  """
  use Phoenix.Component

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Library}
  alias WatchClub.Contents.Content
  alias WatchClubWeb.Helpers.Url

  import WatchClubWeb.Components.UI.{Avatar, LucideIcon}

  attr :user, User, required: true

  @doc """
  An inline user span
  """
  def user_ref(assigns) do
    ~H"""
    <span class="font-bold text-primary">@{@user.username}</span>
    """
  end

  attr :club, Club, required: true

  def club_ref(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 whitespace-nowrap align-middle text-text-subtle">
      <.avatar id={@club.id} name={@club.name} />
      <span class="font-semibold">{@club.name}</span>
    </span>
    """
  end

  attr :library, Library, required: true

  def library_ref(assigns) do
    ~H"""
    <.link
      patch={Url.club_library_link(@library)}
      class="whitespace-nowrap text-accent hover:underline"
    >
      <.lucide_icon
        name={@library.icon}
        class="inline-block size-[1em] align-[-0.15em] shrink-0"
      />
      <span class="font-semibold">{@library.name}</span>
    </.link>
    """
  end

  attr :content, Content, required: true

  def content_link(assigns) do
    ~H"""
    <.link patch={Url.content_details_link(@content)} class="font-bold text-accent hover:underline">
      {@content.implementation.best_localization.title}
    </.link>
    """
  end
end
