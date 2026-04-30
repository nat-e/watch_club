defmodule Shadcn.Components.Command do
  @moduledoc """
  Command palette — searchable list of actions.

      <.command id="quick-cmd">
        <:input placeholder="Type a command..." />
        <:group heading="Suggestions">
          <:item value="new-watch">New watch</:item>
          <:item value="search">Search collection</:item>
        </:group>
        <:group heading="Settings">
          <:item value="profile">Profile</:item>
          <:item value="logout">Sign out</:item>
        </:group>
      </.command>

  Filters items as the user types, supports keyboard navigation
  (arrows, Enter), and emits a `command:select` DOM event with the
  picked value. Pair with `<.dialog>` for a modal command palette.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/command.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/command
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :empty_text, :string, default: "No results found."
  attr :rest, :global

  slot :input do
    attr :placeholder, :string
  end

  slot :group do
    attr :heading, :string
    attr :class, :any
  end

  slot :item do
    attr :value, :string, required: true
    attr :group, :string
    attr :disabled, :boolean
    attr :shortcut, :string
    attr :rest, :any
  end

  def command(assigns) do
    ~H"""
    <div id={@id} data-slot="command" phx-hook="CommandHook" class={["group/command", @class]} {@rest}>
      <div :for={i <- @input} data-slot="command-input-wrapper">
        <div data-slot="command-input-container">
          <Lucideicons.search data-slot="command-input-icon" />
          <input
            type="text"
            data-slot="command-input"
            placeholder={i[:placeholder] || "Type to search..."}
            autocomplete="off"
          />
        </div>
      </div>
      <div data-slot="command-list">
        <div data-slot="command-empty" hidden>
          {@empty_text}
        </div>
        <%= for {g, gi} <- Enum.with_index(@group) do %>
          <div :if={gi > 0} data-slot="command-separator"></div>
          <div data-slot="command-group" data-group-heading={g[:heading]}>
            <div :if={g[:heading]} data-slot="command-group-heading">{g[:heading]}</div>
            <div data-slot="command-group-items">
              <%= for i <- @item, i[:group] == g[:heading] || (i[:group] == nil && gi == 0 && g[:heading] == nil) do %>
                <div
                  role="option"
                  data-slot="command-item"
                  data-value={i.value}
                  data-disabled={i[:disabled] || nil}
                  tabindex="-1"
                >
                  {render_slot(i)}
                  <kbd :if={i[:shortcut]} data-slot="command-shortcut">{i[:shortcut]}</kbd>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
        <%= if @group == [] do %>
          <div data-slot="command-group">
            <div
              :for={i <- @item}
              role="option"
              data-slot="command-item"
              data-value={i.value}
              data-disabled={i[:disabled] || nil}
              tabindex="-1"
            >
              {render_slot(i)}
              <kbd :if={i[:shortcut]} data-slot="command-shortcut">{i[:shortcut]}</kbd>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
