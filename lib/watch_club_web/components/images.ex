defmodule WatchClubWeb.Components.Images do
  use WatchClubWeb, :component

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w92 w154 w185 w342 w500 w780 original), required: true

  slot :inner_block

  def tmdb_poster(assigns) do
    ~H"""
    <div class={[
      "relative aspect-[2/3] overflow-hidden bg-surface-inset",
      @class
    ]}>
      <img
        :if={@path}
        src={"https://image.tmdb.org/t/p/#{@size}/#{@path}"}
        class="absolute inset-0 h-full w-full object-cover"
      />
      <div
        :if={!@path}
        class="absolute inset-0 flex h-full w-full items-center justify-center text-text-muted"
      >
        <Lucideicons.image />
      </div>
      {render_slot(@inner_block)}
    </div>
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
