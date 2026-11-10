defmodule WatchClubWeb.Components.Contents.IncompleteBadge do
  @moduledoc """
  The badge of an Incomplete TV Show, in its poster's corner: a TV Show in the Library with an
  aired TV Show Episode without Media.
  """
  use WatchClubWeb, :component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def incomplete_badge(assigns) do
    ~H"""
    <span
      id={@id}
      role="img"
      aria-label={dgettext("contents", "Some episodes missing")}
      title={dgettext("contents", "Some episodes missing")}
      class={["grid size-7 place-items-center rounded-full bg-black/80", @class]}
      {@rest}
    >
      <Lucideicons.download class="size-icon-sm text-accent" aria-hidden="true" />
    </span>
    """
  end
end
