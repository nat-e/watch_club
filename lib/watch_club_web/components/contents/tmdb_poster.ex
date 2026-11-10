defmodule WatchClubWeb.Components.Contents.TmdbPoster do
  @moduledoc """
  TMDB poster image component for content surfaces. A `path` is a TMDB image path,
  or an image URL for a Sports Event.
  """
  use WatchClubWeb, :component

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w92 w154 w185 w342 w500 w780 original), required: true
  attr :alt, :string, default: ""

  slot :inner_block

  def tmdb_poster(assigns) do
    ~H"""
    <.tmdb_image path={@path} size={@size} alt={@alt} class={["aspect-2/3 rounded-lg", @class]}>
      {render_slot(@inner_block)}
    </.tmdb_image>
    """
  end

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, values: ~w(w92 w185 w300 original), required: true
  attr :alt, :string, default: ""

  slot :inner_block

  def tmdb_still(assigns) do
    ~H"""
    <.tmdb_image path={@path} size={@size} alt={@alt} class={["aspect-16/9", @class]}>
      {render_slot(@inner_block)}
    </.tmdb_image>
    """
  end

  attr :class, :any, default: nil
  attr :path, :string, default: nil
  attr :size, :string, required: true
  attr :alt, :string, default: ""

  slot :inner_block

  defp tmdb_image(assigns) do
    ~H"""
    <div class={[
      "relative overflow-hidden bg-surface-inset",
      @class
    ]}>
      <img
        :if={@path}
        src={tmdb_image_url(@path, @size)}
        alt={@alt}
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

  @doc "The URL of a TMDB image path at this size; an image URL stays as it is."
  def tmdb_image_url("http" <> _ = url, _size), do: url
  def tmdb_image_url(path, size), do: "https://image.tmdb.org/t/p/#{size}/#{path}"
end
