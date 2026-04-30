defmodule Shadcn.Components.InputOtp do
  @moduledoc """
  One-time-password / verification-code input.

      <.input_otp id="otp" name="otp" length={6} />
      <.input_otp id="otp" name="otp" length={6} groups={[3, 3]} />

  Renders one cell per character, backed by a hidden `<input>` for form
  submission. The hook handles typing, deletion, paste of a full code,
  and arrow-key navigation across cells.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/input-otp.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/input-otp
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :value, :string, default: ""
  attr :length, :integer, default: 6
  attr :groups, :list, default: nil, doc: "list of group sizes; defaults to a single group"
  attr :pattern, :string, default: "[0-9]*"
  attr :disabled, :boolean, default: false
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField
  attr :rest, :global

  def input_otp(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id,
      name: field.name,
      value: to_string(field.value || ""),
      errors: errors
    )
    |> input_otp()
  end

  def input_otp(assigns) do
    groups = assigns.groups || [assigns.length]
    assigns = assign(assigns, :groups, groups)

    ~H"""
    <div
      id={@id}
      data-slot="input-otp"
      data-disabled={@disabled || nil}
      phx-hook="InputOtpHook"
      class={["group/input-otp", @class]}
      {@rest}
    >
      <input
        type="text"
        id={"#{@id}-hidden"}
        name={@name}
        value={@value}
        maxlength={@length}
        pattern={@pattern}
        disabled={@disabled}
        autocomplete="one-time-code"
        inputmode="numeric"
        aria-invalid={@errors != [] && "true"}
        data-slot="input-otp-input"
      />
      <div
        :for={{size, gi} <- Enum.with_index(@groups)}
        data-slot="input-otp-group"
        data-group-index={gi}
      >
        <%= for ci <- 0..(size - 1) do %>
          <div
            data-slot="input-otp-slot"
            data-cell-index={cell_index(@groups, gi, ci)}
            aria-hidden="true"
          >
          </div>
        <% end %>
      </div>
      <div :if={length(@groups) > 1} data-slot="input-otp-separator-row" aria-hidden="true"></div>
    </div>
    """
  end

  defp cell_index(groups, gi, ci) do
    Enum.take(groups, gi) |> Enum.sum() |> Kernel.+(ci)
  end
end
