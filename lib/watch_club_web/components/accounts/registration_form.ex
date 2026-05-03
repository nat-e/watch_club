defmodule WatchClubWeb.Components.Accounts.RegistrationForm do
  use WatchClubWeb, :component
  alias Ash.Error.Changes.{InvalidAttribute, Required}

  import WatchClubWeb.Components.Forms

  attr :form, Phoenix.HTML.Form, required: true

  def registration_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="setup-form"
      phx-change="validate_registration"
      phx-submit="submit_registration"
      class="flex flex-col gap-6"
      phx-mounted={JS.focus_first()}
    >
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
      <div class="flex flex-col gap-2">
        <.label field={@form[:password_confirmation]}>Confirm password</.label>
        <.input
          field={@form[:password_confirmation]}
          type="password"
          autocomplete="new-password"
          phx-debounce="blur"
        />
        <.field_errors field={@form[:password_confirmation]} />
      </div>
      <.button type="submit" class="w-full">
        Create account
      </.button>
    </.form>
    """
  end

  def registration_form_opts(invitation_id \\ nil) do
    [
      # Append invitation_id before validate/submit without requiring a hidden field
      prepare_params: fn params, _ -> Map.put(params, :invitation_id, invitation_id) end,
      context: %{token_type: :sign_in},
      transform_errors: fn
        _, %Required{field: :username} ->
          {:username, "You must define a username", []}

        _, %InvalidAttribute{field: :username, vars: [min: min]} ->
          {:username, "Username must be at least %{min} characters", min: min}

        _, %InvalidAttribute{field: :username, vars: [max: max]} ->
          {:username, "Username cannot be longer than %{max} characters", max: max}

        _, %InvalidAttribute{field: :username, vars: [regex: _]} ->
          {:username, "Username can only contain lower case letters, numbers and _", []}

        _, %Required{field: :password} ->
          {:password, "You must define a password", []}

        _, %InvalidAttribute{field: :password, vars: [min: min]} ->
          {:password, "Password must be at least %{min} characters", min: min}

        _, %InvalidAttribute{field: :password, vars: [max: max]} ->
          {:password, "Password cannot be longer than %{max} characters", max: max}

        _, %_{field: :password_confirmation} ->
          {:password_confirmation, "Passwords do not match", []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
