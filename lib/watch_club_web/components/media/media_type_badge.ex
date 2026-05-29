defmodule WatchClubWeb.Components.Media.MediaTypeBadge do
  @moduledoc """
  Icons for `Media.MediaType` values.

  Shared across the admin media surfaces (Media Browser, Media Imports) and
  any future Media-aware screen. Renders the canonical Lucide icon for each
  media type. The primitive owns icon sizing by default; composers pass a
  size token (`size-icon-sm`, `size-icon-lg`, etc.) only when they need to
  override it.
  """
  use WatchClubWeb, :component

  attr :media_type, :atom, required: true

  def media_type_badge(assigns) do
    ~H"""
    <.badge variant="accent">
      <:icon><.media_type_icon media_type={@media_type} /></:icon>
      {WatchClub.MediaCatalog.MediaType.translated_plural_label(@media_type)}
    </.badge>
    """
  end

  defp media_type_icon(%{media_type: :movie} = assigns) do
    ~H"""
    <Lucideicons.clapperboard />
    """
  end

  defp media_type_icon(%{media_type: :tv_show_episode} = assigns) do
    ~H"""
    <Lucideicons.tv />
    """
  end

  defp media_type_icon(%{media_type: :ebook} = assigns) do
    ~H"""
    <Lucideicons.book_open />
    """
  end

  defp media_type_icon(%{media_type: :audiobook} = assigns) do
    ~H"""
    <Lucideicons.headphones />
    """
  end
end
