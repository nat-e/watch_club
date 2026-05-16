defmodule WatchClubWeb.Components.UI.Input do
  @moduledoc """
  Token-driven Watch Club input primitive.
  """

  use Phoenix.Component

  attr :id, :any, default: nil
  attr :class, :any, default: nil
  attr :type, :string, default: "text"
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :errors, :list, default: []
  attr :field, Phoenix.HTML.FormField, doc: "form field — derives id, name, value, errors"

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture disabled form list max maxlength min minlength multiple pattern placeholder readonly required size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(
      field: nil,
      id: assigns.id || field.id,
      name: field.name,
      value: field.value,
      errors: errors
    )
    |> input()
  end

  def input(assigns) do
    ~H"""
    <input
      id={@id}
      type={@type}
      name={@name}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      aria-invalid={@errors != [] && "true"}
      data-slot="input"
      class={[
        "h-control-md w-full min-w-0 rounded-control border border-border bg-surface-inset px-group py-related text-base text-text transition-[border-color,box-shadow,color] outline-none placeholder:text-text-subtle md:text-sm",
        "focus-visible:border-border-focus focus-visible:ring-2 focus-visible:ring-border-focus/40",
        "disabled:pointer-events-none disabled:cursor-not-allowed disabled:border-border-subtle disabled:text-text-disabled disabled:placeholder:text-text-disabled",
        "aria-invalid:border-danger-border aria-invalid:ring-2 aria-invalid:ring-danger/30",
        "file:mr-3 file:inline-flex file:h-7 file:border-0 file:bg-transparent file:px-0 file:text-sm file:font-medium file:text-text disabled:file:text-text-disabled",
        @class
      ]}
      {@rest}
    />
    """
  end
end
