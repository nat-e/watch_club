defmodule Shadcn.Components.Tabs do
  @moduledoc """
  Tabbed panels — horizontal or vertical.

      <.tabs id="account-tabs" value="profile">
        <:tab id="profile" label="Profile">
          Edit your profile here.
        </:tab>
        <:tab id="password" label="Password">
          Change your password.
        </:tab>
        <:tab id="settings" label="Settings" disabled>
          Settings (coming soon).
        </:tab>
      </.tabs>

  Tab switching is fully client-side via the `TabsHook`. Pass `value` to set
  the initial selected tab. Mirrors Radix's controlled-on-mount behavior.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/tabs.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/tabs
  Radix doc: https://www.radix-ui.com/primitives/docs/components/tabs
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :value, :string, default: nil
  attr :variant, :string, values: ~w(default line), default: "default"
  attr :orientation, :string, values: ~w(horizontal vertical), default: "horizontal"
  attr :rest, :global

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :label, :string, required: true
    attr :disabled, :boolean
    attr :class, :any
  end

  def tabs(assigns) do
    active = assigns.value || (List.first(assigns.tab) || %{})[:id]
    assigns = assign(assigns, :active, active)

    ~H"""
    <div
      id={@id}
      data-slot="tabs"
      data-orientation={@orientation}
      phx-hook="TabsHook"
      class={["group/tabs", @class]}
      {@rest}
    >
      <div data-slot="tabs-list" data-variant={@variant} role="tablist" class="group/tabs-list">
        <button
          :for={t <- @tab}
          type="button"
          role="tab"
          id={"#{@id}-trigger-#{t.id}"}
          data-slot="tabs-trigger"
          data-tab-id={t.id}
          data-state={if t.id == @active, do: "active", else: "inactive"}
          data-active={if t.id == @active, do: "true", else: nil}
          aria-selected={if t.id == @active, do: "true", else: "false"}
          aria-controls={"#{@id}-content-#{t.id}"}
          tabindex={if t.id == @active, do: "0", else: "-1"}
          disabled={t[:disabled]}
        >
          {t.label}
        </button>
      </div>
      <div
        :for={t <- @tab}
        id={"#{@id}-content-#{t.id}"}
        role="tabpanel"
        data-slot="tabs-content"
        data-tab-id={t.id}
        data-state={if t.id == @active, do: "active", else: "inactive"}
        aria-labelledby={"#{@id}-trigger-#{t.id}"}
        hidden={t.id != @active}
        class={t[:class]}
      >
        {render_slot(t)}
      </div>
    </div>
    """
  end
end
