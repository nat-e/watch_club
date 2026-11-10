defmodule WatchClubWeb.Components.Contents.TmdbBackdrop do
  @moduledoc """
  TMDB backdrop image component for content surfaces. A `path` is a TMDB image path,
  or an image URL for a Sports Event.
  """
  use WatchClubWeb, :component

  alias WatchClubWeb.Components.Contents.TmdbPoster

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w300 w780 w1280 original), required: true
  attr :alt, :string, default: ""
  attr :rest, :global

  def tmdb_backdrop(assigns) do
    ~H"""
    <img src={TmdbPoster.tmdb_image_url(@path, @size)} alt={@alt} class={@class} {@rest} />
    """
  end
end
