defmodule WatchClubWeb.Components.Accounts.SignInForm do
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Forms

  attr :form, Phoenix.HTML.Form, required: true

  def sign_in_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="signin-form"
      phx-change="validate_sign_in"
      phx-submit="submit_sign_in"
      class="flex flex-col gap-6"
      phx-mounted={JS.focus_first()}
    >
      <.input_with_label
        field={@form[:username]}
        label={dgettext("auth", "Username")}
        autocomplete="username"
        type="text"
      />
      <.input_with_label
        field={@form[:password]}
        label={dgettext("auth", "Password")}
        autocomplete="password"
        type="password"
      />
      <.field_errors field={@form[:invitation_id]} show_untouched={true} />
      <.button type="submit" class="w-full">
        {dgettext("auth", "Sign in")}
      </.button>
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
