defmodule WatchClubWeb.Components.Settings.SettingsSection do
  @moduledoc """
  Section wrapper for settings pages.
  """
  use WatchClubWeb, :component

  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :any, default: nil

  slot :action
  slot :inner_block, required: true

  def settings_section(assigns) do
    ~H"""
    <.card padding="cluster" class={["w-full", @class]}>
      <.stack space="cluster">
        <.inline
          space="group"
          class="flex-col items-start sm:flex-row sm:items-start sm:justify-between"
        >
          <.stack space="tight" class="min-w-0">
            <h2 class="text-xl font-semibold tracking-tight text-text">{@title}</h2>
            <p :if={@description} class="max-w-readable text-sm leading-6 text-text-muted">
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
