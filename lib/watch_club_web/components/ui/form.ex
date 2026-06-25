defmodule WatchClubWeb.Components.UI.Form do
  @moduledoc """
  Token-driven Watch Club form primitives.

  The form wrapper keeps Phoenix form semantics while adding a default
  field/action rhythm. The field primitive owns label, control, hint,
  and error spacing.
  """

  use Phoenix.Component

  import WatchClubWeb.Components.UI.Input
  import WatchClubWeb.Components.UI.Label

  attr :id, :string, required: true
  attr :for, :any, required: true
  attr :class, :any, default: nil

  attr :layout, :string,
    values: ~w(stack none),
    default: "stack",
    doc: "Use `stack` for standard forms and `none` for forms that are already custom layouts."

  attr :action_class, :any, default: nil

  attr :rest, :global,
    include:
      ~w(as csrf_token errors method multipart autocomplete name rel enctype novalidate target phx-change phx-submit phx-target phx-trigger-action phx-mounted phx-update phx-hook)

  slot :inner_block, required: true

  slot :action do
    attr :class, :any
  end

  def form(assigns) do
    ~H"""
    <Phoenix.Component.form
      id={@id}
      for={@for}
      class={[@layout == "stack" && "flex flex-col gap-cluster", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}

      <div
        :for={action <- @action}
        data-slot="form-action"
        class={[
          "flex flex-col-reverse gap-related sm:flex-row sm:justify-end",
          @action_class,
          action[:class]
        ]}
      >
        {render_slot(action)}
      </div>
    </Phoenix.Component.form>
    """
  end

  attr :field, Phoenix.HTML.FormField, default: nil
  attr :errors, :list, default: []
  attr :class, :any, default: nil
  attr :show_untouched, :boolean, default: false
  attr :rest, :global

  def field_errors(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if assigns.show_untouched || used_input?(field), do: field.errors, else: []

    assigns
    |> assign(:field, nil)
    |> assign(:errors, errors)
    |> field_errors()
  end

  def field_errors(assigns) do
    ~H"""
    <p
      :for={msg <- @errors}
      data-slot="field-error"
      class={["text-sm leading-6 text-danger", @class]}
      {@rest}
    >
      {translate(msg)}
    </p>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :class, :any, default: nil
  attr :input_class, :any, default: nil
  attr :type, :string, default: "text"
  attr :debounce, :string, default: "blur"
  attr :show_untouched, :boolean, default: false

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture disabled form list max maxlength min minlength multiple pattern placeholder readonly required size step)

  slot :control
  slot :hint

  def field(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if assigns.show_untouched || used_input?(field), do: field.errors, else: []
    assigns = assign(assigns, :errors, errors)

    ~H"""
    <div data-slot="field" class={["grid gap-related", @class]}>
      <.label field={@field}>{@label}</.label>

      <p
        :for={hint <- @hint}
        data-slot="field-hint"
        class="text-sm leading-6 text-text-muted"
      >
        {render_slot(hint)}
      </p>

      <%= if @control == [] do %>
        <.input
          field={@field}
          type={@type}
          class={@input_class}
          phx-debounce={@debounce}
          {@rest}
        />
      <% else %>
        {render_slot(@control)}
      <% end %>

      <p
        :for={msg <- @errors}
        data-slot="field-error"
        class="text-sm leading-6 text-danger"
      >
        {translate(msg)}
      </p>
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
