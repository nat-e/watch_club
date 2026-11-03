defmodule WatchClubWeb.Components.UI.Badges do
  @moduledoc """
  A collection of Badges and similar inline components for displaying a Resource in a
  standardized manner
  """
  use Phoenix.Component
  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Accounts.User
  alias WatchClub.Clubs.{Club, Library}
  alias WatchClub.Contents.Content
  alias WatchClubWeb.Helpers.Url

  import WatchClubWeb.Components.UI.{Avatar, LucideIcon}

  attr :user, User

  @doc """
  An inline user span
  """
  def user_ref(%{user: nil} = assigns) do
    ~H"""
    <span class="font-semibold text-text-subtle">{dgettext("default", "@Deleted user")}</span>
    """
  end

  def user_ref(assigns) do
    ~H"""
    <span class="font-semibold text-primary">@{@user.username}</span>
    """
  end

  attr :club, Club, required: true
  attr :selected, :boolean, default: false

  def club_ref(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 whitespace-nowrap align-middle min-w-0",
      @selected && "text-text",
      !@selected && "text-text-subtle"
    ]}>
      <.avatar id={@club.id} name={@club.name} />
      <span class="font-semibold truncate">{@club.name}</span>
    </span>
    """
  end

  attr :library, Library, required: true

  def library_ref(assigns) do
    ~H"""
    <.link
      navigate={Url.club_library_link(@library)}
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
    <.link
      navigate={Url.content_details_link(@content)}
      class="font-semibold text-accent hover:underline"
    >
      {@content.implementation.best_localization.title}
    </.link>
    """
  end
end
