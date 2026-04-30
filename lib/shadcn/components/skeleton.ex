defmodule Shadcn.Components.Skeleton do
  @moduledoc """

  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  def skeleton(assigns) do
    ~H"""
    <div
      data-slot="skeleton"
      class={@class}
      {@rest}
    />
    """
  end
end
