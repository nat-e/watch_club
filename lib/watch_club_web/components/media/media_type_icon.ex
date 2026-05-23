defmodule WatchClubWeb.Components.Media.MediaTypeIcon do
  @moduledoc """
  Icons for `Media.MediaType` values.

  Shared across the admin media surfaces (Media Browser, Media Imports) and
  any future Media-aware screen. Renders the canonical Lucide icon for each
  media type. The primitive owns icon sizing by default; composers pass a
  size token (`size-icon-sm`, `size-icon-lg`, etc.) only when they need to
  override it.
  """
  use WatchClubWeb, :component

  attr :class, :any, default: "size-icon"
  attr :media_type, :atom, required: true, values: [:movie, :tv_show_episode, :ebook, :audiobook]

  def media_type_icon(%{media_type: :movie} = assigns) do
    ~H"""
    <Lucideicons.clapperboard class={@class} />
    """
  end

  def media_type_icon(%{media_type: :tv_show_episode} = assigns) do
    ~H"""
    <Lucideicons.tv class={@class} />
    """
  end

  def media_type_icon(%{media_type: :ebook} = assigns) do
    ~H"""
    <Lucideicons.book_open class={@class} />
    """
  end

  def media_type_icon(%{media_type: :audiobook} = assigns) do
    ~H"""
    <Lucideicons.headphones class={@class} />
    """
  end
end
