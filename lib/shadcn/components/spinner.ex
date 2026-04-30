defmodule Shadcn.Components.Spinner do
  @moduledoc """

  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  def spinner(assigns) do
    ~H"""
    <Lucideicons.loader
      data-slot="spinner"
      role="status"
      aria-label="Loading"
      class={@class}
      {@rest}
    />
    """
  end
end
