defmodule WatchClubWeb.Components.Settings.SettingsHeader do
  @moduledoc """
  Header for settings pages.
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
        class="text-xs font-semibold tracking-wider text-accent uppercase"
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
end
