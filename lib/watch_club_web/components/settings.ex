defmodule WatchClubWeb.Components.Settings do
  @moduledoc """
  Shared building blocks for settings pages.
  """
  use WatchClubWeb, :component

  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :any, default: nil

  slot :action
  slot :inner_block, required: true

  def settings_section(assigns) do
    ~H"""
    <.card padding="cluster" class={["w-full max-w-panel", @class]}>
      <.stack space="cluster">
        <.inline space="group" class="flex-col items-end sm:flex-row sm:justify-between">
          <.stack space="tight">
            <h2 class="text-lg font-semibold leading-none tracking-tight">{@title}</h2>
            <p :if={@description} class="text-sm text-text-muted">
              {@description}
            </p>
          </.stack>
          <div :if={@action != []} class="shrink-0">
            {render_slot(@action)}
          </div>
        </.inline>
        <.stack space="cluster">
          {render_slot(@inner_block)}
        </.stack>
      </.stack>
    </.card>
    """
  end
end
