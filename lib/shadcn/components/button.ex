defmodule Shadcn.Components.Button do
  @moduledoc """
  Clickable action: triggers an event, submits a form, navigates, or opens an overlay.

  Renders a `<button>` by default. Renders a `<.link>` when `href`, `navigate`,
  or `patch` is passed (the equivalent of shadcn's `asChild` + Link pattern).

  When rendered as a link, `disabled` is translated to `aria-disabled="true"`,
  `tabindex="-1"`, and `data-disabled`, since `<a>` ignores the HTML `disabled`
  attribute. Pair with `pointer-events: none` in CSS via the data attribute.

  For loading states, set `aria-busy="true"` so assistive tech announces it.

      <.button>Save</.button>
      <.button variant="destructive" size="sm">Delete</.button>
      <.button navigate={~p"/dashboard"} variant="outline">Dashboard</.button>
      <.button>
        <:icon position="start"><Lucideicons.plus /></:icon>
        New item
      </.button>
      <.button disabled aria-busy="true">
        <:icon position="end"><Lucideicons.refresh_cw class="animate-spin" /></:icon>
        Saving...
      </.button>
      <.button variant="outline" size="icon" aria-label="Open menu">
        <:icon><Lucideicons.plus /></:icon>
      </.button>

  Ported from Shadcn on 2026-04-27
  Commit: 44c09a19b0658cf8e72ac84bbba5b76e05192a0d
  Source: https://github.com/shadcn-ui/ui/blob/44c09a19b0658cf8e72ac84bbba5b76e05192a0d/apps/v4/styles/radix-vega/ui/button.tsx
  """
  use Phoenix.Component

  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(default outline secondary ghost destructive link),
    default: "default"

  attr :size, :string,
    values: ~w(xs sm default lg icon-xs icon-sm icon icon-lg),
    default: "default"

  attr :type, :string, values: ~w(button submit reset), default: "button"

  attr :rest, :global,
    include:
      ~w(disabled form name value autofocus href navigate patch method download replace target)

  slot :icon do
    attr :position, :string, values: ~w(start end)
  end

  slot :inner_block, required: true

  def button(%{rest: rest, disabled: true})
      when is_map_key(rest, :href) or
             is_map_key(rest, :navigate) or
             is_map_key(rest, :patch) do
    raise ArgumentError, """
    <.button> cannot be both `disabled` and a link (href/navigate/patch).
    Use a real <button>, or conditionally render the link.
    """
  end

  def button(%{rest: rest} = assigns)
      when is_map_key(rest, :href) or
             is_map_key(rest, :navigate) or
             is_map_key(rest, :patch) do
    ~H"""
    <.link
      data-slot="button"
      data-variant={@variant}
      data-size={@size}
      class={["group/button", @class]}
      {@rest}
    >
      <.button_content icon={@icon}>
        {render_slot(@inner_block)}
      </.button_content>
    </.link>
    """
  end

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      data-slot="button"
      data-variant={@variant}
      data-size={@size}
      class={["group/button", @class]}
      {@rest}
    >
      <.button_content icon={@icon}>
        {render_slot(@inner_block)}
      </.button_content>
    </button>
    """
  end

  defp button_content(assigns) do
    ~H"""
    <%= for i <- @icon, i[:position] == "start" or is_nil(i[:position]) do %>
      {render_slot(i)}
    <% end %>
    {render_slot(@inner_block)}
    <%= for i <- @icon, i[:position] == "end" do %>
      {render_slot(i)}
    <% end %>
    """
  end
end
