defmodule WatchClubWeb.Components.Media.SourceTypeIcon do
  @moduledoc """
  Visual icon for a `Source.Type`. Filesystem and Sportarr use a Lucide icon in a
  bordered chip; `radarr` / `sonarr` use the product's official SVG.
  Sizing options:

    * `"header"` / `"card"` — fits `size-control-md` (40px).
    * `"empty"` — fits the icon slot of `<.empty>` (large).
    * `"title"` — fits a line of title text, such as a modal's.
  """
  use WatchClubWeb, :component

  attr :type, :atom, required: true, values: [:filesystem, :radarr, :sonarr, :sportarr]

  attr :size, :string,
    values: ~w(header card empty title),
    default: "card"

  attr :class, :any, default: nil

  def source_type_icon(%{type: type} = assigns) when type in [:filesystem, :sportarr] do
    ~H"""
    <span class={[
      "grid shrink-0 place-items-center rounded-md border border-border bg-surface text-text-muted",
      box_classes(@size),
      @class
    ]}>
      <Lucideicons.hard_drive :if={@type == :filesystem} class={icon_classes(@size)} />
      <Lucideicons.trophy :if={@type == :sportarr} class={icon_classes(@size)} />
    </span>
    """
  end

  def source_type_icon(%{type: type} = assigns) when type in [:radarr, :sonarr] do
    ~H"""
    <span class={["inline-grid shrink-0 place-items-center", box_classes(@size), @class]}>
      <img
        src={"/images/source_types/#{@type}.svg"}
        alt={"#{@type} logo"}
        class={image_classes(@size)}
      />
    </span>
    """
  end

  defp box_classes("header"), do: "size-control-md"
  defp box_classes("card"), do: "size-control-md"
  defp box_classes("empty"), do: "size-icon-xl"
  defp box_classes("title"), do: "size-icon"

  defp icon_classes("empty"), do: "size-icon-lg"
  defp icon_classes("title"), do: "size-icon-sm"
  defp icon_classes(_), do: "size-icon"

  defp image_classes("empty"), do: "size-icon-xl"
  defp image_classes("title"), do: "size-icon"
  defp image_classes(_), do: "size-control-md"
end
