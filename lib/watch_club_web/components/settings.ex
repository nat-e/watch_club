defmodule WatchClubWeb.Components.Settings do
  @moduledoc """
  Shared building blocks for settings pages.
  """
  use WatchClubWeb, :component

  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :eyebrow, :string, default: nil
  attr :class, :any, default: nil

  slot :inner_block

  def settings_header(assigns) do
    ~H"""
    <.stack space="related" class={["max-w-readable", @class]}>
      <p
        :if={@eyebrow}
        class="text-xs font-semibold tracking-[0.22em] text-accent uppercase"
      >
        {@eyebrow}
      </p>
      <.stack space="tight">
        <h1 class="text-3xl font-semibold tracking-tight text-text sm:text-4xl">
          {@title}
        </h1>
        <p :if={@description} class="text-base leading-7 text-text-muted">
          {@description}
        </p>
      </.stack>
      {render_slot(@inner_block)}
    </.stack>
    """
  end

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
