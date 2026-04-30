defmodule WatchClubWeb.Components.Forms.FieldErrors do
  @moduledoc """
  Styled component for displaying Form field errors.
  When errors are present (and the form has been interacted with per `Phoenix.Component.used_input?/1`),
  the errors will be rendered.
  """
  use Phoenix.Component

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :class, :any, default: nil
  attr :rest, :global

  def field_errors(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns |> assign(:field, nil) |> assign(:errors, errors) |> field_errors()
  end

  def field_errors(assigns) do
    ~H"""
    <p
      :for={msg <- @errors}
      data-slot="field-error"
      class={["text-destructive text-sm", @class]}
      {@rest}
    >
      {translate(msg)}
    </p>
    """
  end

  defp translate({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(WatchClubWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(WatchClubWeb.Gettext, "errors", msg, opts)
    end
  end

  defp translate(msg) when is_binary(msg), do: msg
end
