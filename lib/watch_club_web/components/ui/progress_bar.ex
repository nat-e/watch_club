defmodule WatchClubWeb.Components.UI.ProgressBar do
  @moduledoc """
  How far something got, as a thin pink bar filling up from the left. It's decorative: the text
  next to it says what it measures.
  """

  use Phoenix.Component

  attr :percent, :any, required: true, doc: "a number from 0 to 100"
  attr :class, :any, default: nil

  def progress_bar(assigns) do
    ~H"""
    <span
      aria-hidden="true"
      class={["block h-1 overflow-hidden rounded-full bg-surface-raised", @class]}
    >
      <span class="block h-full rounded-full bg-primary" style={"width: #{@percent}%"}></span>
    </span>
    """
  end
end
