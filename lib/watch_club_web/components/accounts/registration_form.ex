defmodule WatchClubWeb.Components.Accounts.RegistrationForm do
  use WatchClubWeb, :component

  attr :change, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :id, :string, required: true
  attr :submit, :string, required: true
  attr :target, :any, default: nil

  def registration_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id={@id}
      phx-change={@change}
      phx-submit={@submit}
      phx-target={@target}
      phx-mounted={JS.focus_first()}
    >
      <.field
        field={@form[:username]}
        label={dgettext("auth", "Username")}
        autocomplete="username"
        type="text"
      />
      <.field
        field={@form[:password]}
        label={dgettext("auth", "Password")}
        autocomplete="new-password"
        type="password"
      />
      <.field
        field={@form[:password_confirmation]}
        label={dgettext("auth", "Confirm password")}
        autocomplete="new-password"
        type="password"
      />
      <.field_errors field={@form[:invitation_id]} show_untouched={true} />
      <:action>
        <.button id={"#{@id}-submit-button"} type="submit" class="w-full">
          {dgettext("auth", "Create account")}
        </.button>
      </:action>
    </.form>
    """
  end

  def registration_form_opts(locale, invitation_id \\ nil) do
    [
      # Append locale and invitation_id before validate/submit without requiring a hidden field
      prepare_params: fn params, _ ->
        params |> Map.put(:invitation_id, invitation_id) |> Map.put(:locale, locale)
      end,
      context: %{token_type: :sign_in}
    ]
  end
end
