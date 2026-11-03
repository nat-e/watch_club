defmodule WatchClubWeb.Components.Contents.Details.DetailsBackdrop do
  @moduledoc """
  Full-bleed backdrop layer for content detail pages: the backdrop image
  faded under stacked gradient scrims that keep foreground content readable.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbBackdrop

  attr :path, :string, default: nil

  def details_backdrop(assigns) do
    ~H"""
    <.tmdb_backdrop
      :if={@path}
      path={@path}
      size="w1280"
      alt=""
      aria-hidden="true"
      class="absolute inset-0 h-full w-full object-cover opacity-40"
    />
    <div
      aria-hidden="true"
      class="absolute inset-0 bg-linear-to-r from-canvas via-canvas/80 to-canvas/40"
    >
    </div>
    <div
      aria-hidden="true"
      class="absolute inset-0 bg-linear-to-b from-canvas/10 via-canvas/80 to-canvas"
    >
    </div>
    <div
      aria-hidden="true"
      class="absolute inset-0 bg-[radial-gradient(circle_at_28%_18%,var(--wc-color-primary-bg),transparent_34rem)]"
    >
    </div>
    """
  end
end
