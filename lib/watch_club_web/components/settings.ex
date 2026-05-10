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
    <section class={[
      "flex w-full max-w-3xl flex-col gap-6 p-6",
      @class
    ]}>
      <div class="flex flex-col gap-4 sm:flex-row items-end sm:justify-between">
        <div class="flex flex-col gap-1">
          <h2 class="text-lg font-semibold leading-none tracking-tight">{@title}</h2>
          <p :if={@description} class="text-muted-foreground text-sm">
            {@description}
          </p>
        </div>
        <div :if={@action != []} class="shrink-0">
          {render_slot(@action)}
        </div>
      </div>
      <div class="flex flex-col gap-6">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end
end
