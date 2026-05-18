defmodule WatchClubWeb.Components.Accounts.SignInForm do
  use WatchClubWeb, :component

  attr :change, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :id, :string, required: true
  attr :submit, :string, required: true
  attr :target, :any, default: nil

  def sign_in_form(assigns) do
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
        autocomplete="password"
        type="password"
      />
      <.field_errors field={@form[:invitation_id]} show_untouched={true} />
      <:action>
        <.button id={"#{@id}-submit-button"} type="submit" class="w-full">
          {dgettext("auth", "Sign in")}
        </.button>
      </:action>
    </.form>
    """
  end

  def sign_in_form_opts(invitation_id \\ nil) do
    [
      # Append invitation_id before validate/submit without requiring a hidden field
      prepare_params: fn params, _ -> Map.put(params, :invitation_id, invitation_id) end,
      context: %{token_type: :sign_in},
      transform_errors: fn
        _, %AshAuthentication.Errors.AuthenticationFailed{} ->
          {:password, dgettext("errors", "Your username or password is invalid"), []}

        _, err ->
          err
      end
    ]
  end
end
