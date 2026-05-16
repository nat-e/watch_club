defmodule WatchClubWeb.Components.Libraries.LibraryIcon do
  @moduledoc """
  Icon for a WatchClub library.
  """
  use WatchClubWeb, :component

  attr :class, :any, default: nil
  attr :library, Library, required: true
  attr :rest, :global

  def library_icon(assigns) do
    ~H"""
    <.lucide_icon name={@library.icon} class={@class} {@rest} />
    """
  end
end
