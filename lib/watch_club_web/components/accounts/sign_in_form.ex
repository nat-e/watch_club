defmodule WatchClubWeb.Components.Accounts.SignInForm do
  alias Ash.Error.Query.Required
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
      <.input
        field={@form[:invitation_id]}
        type="text"
        class="hidden"
      />
      <div class="flex flex-col gap-2">
        <.label field={@form[:username]}>Username</.label>
        <.input
          field={@form[:username]}
          type="text"
          autocomplete="username"
          phx-debounce="blur"
        />
        <.field_errors field={@form[:username]} />
      </div>
      <div class="flex flex-col gap-2">
        <.label field={@form[:password]}>Password</.label>
        <.input
          field={@form[:password]}
          type="password"
          autocomplete="new-password"
          phx-debounce="blur"
        />
        <.field_errors field={@form[:password]} />
      </div>
      <.button type="submit" class="w-full">
        Sign in
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
        _, %Required{field: :username} ->
          {:username, "You must enter your username", []}

        _, %Required{field: :password} ->
          {:password, "You must enter your password", []}

        _, %AshAuthentication.Errors.AuthenticationFailed{} ->
          {:password, "Your username or password was invalid", []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
