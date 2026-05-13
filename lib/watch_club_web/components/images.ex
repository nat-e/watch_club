defmodule WatchClubWeb.Components.Images do
  use WatchClubWeb, :component

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w92 w154 w185 w342 w500 w780 original), required: true

  def tmdb_poster(%{path: nil} = assigns) do
    ~H"""
    <div class={[
      "relative flex size-full aspect-[2/3] items-center justify-center rounded-md border-border-subtle bg-surface-inset",
      @class
    ]}>
      <Lucideicons.image />
    </div>
    """
  end

  def tmdb_poster(assigns) do
    ~H"""
    <img src={"https://image.tmdb.org/t/p/#{@size}/#{@path}"} class={@class} />
    """
  end

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w300 w780 w1280 original), required: true

  def tmdb_backdrop(assigns) do
    ~H"""
    <img src={"https://image.tmdb.org/t/p/#{@size}/#{@path}"} class={@class} />
    """
  end
end
