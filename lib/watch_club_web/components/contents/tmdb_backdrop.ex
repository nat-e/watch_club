defmodule WatchClubWeb.Components.Contents.TmdbBackdrop do
  @moduledoc """
  TMDB backdrop image component for content surfaces.
  """
  use WatchClubWeb, :component

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w300 w780 w1280 original), required: true
  attr :alt, :string, default: ""
  attr :rest, :global

  def tmdb_backdrop(assigns) do
    ~H"""
    <img src={"https://image.tmdb.org/t/p/#{@size}/#{@path}"} alt={@alt} class={@class} {@rest} />
    """
  end
end
