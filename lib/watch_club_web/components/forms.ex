defmodule WatchClubWeb.Components.Forms do
  @moduledoc """
  Styled component for displaying Form field errors.
  When errors are present (and the form has been interacted with per `Phoenix.Component.used_input?/1`),
  the errors will be rendered.
  """
  use WatchClubWeb, :component

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :class, :any, default: nil
  attr :show_untouched, :boolean, default: false
  attr :rest, :global

  def field_errors(
        %{show_untouched: show_untouched, field: %Phoenix.HTML.FormField{} = field} = assigns
      ) do
    errors = if show_untouched || used_input?(field), do: field.errors, else: []

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

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :class, :string, default: nil
  attr :debounce, :string, default: "blur"

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture disabled form list max maxlength min minlength multiple pattern placeholder readonly required size step)

  slot :inner_block

  @spec input_with_label(map()) :: Phoenix.LiveView.Rendered.t()
  def input_with_label(assigns) do
    ~H"""
    <div class={["flex flex-col gap-2", @class]}>
      <.label field={@field}>{@label}</.label>
      {render_slot(@inner_block)}
      <.input
        :if={@inner_block == []}
        field={@field}
        phx-debounce={@debounce}
        {@rest}
      />
      <.field_errors field={@field} />
    </div>
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
