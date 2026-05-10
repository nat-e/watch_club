defmodule WatchClubWeb.Components.Accounts.RegistrationForm do
  use WatchClubWeb, :component

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
      <.input_with_label
        field={@form[:username]}
        label={dgettext("auth", "Username")}
        autocomplete="username"
        type="text"
      />
      <.input_with_label
        field={@form[:password]}
        label={dgettext("auth", "Password")}
        autocomplete="new-password"
        type="password"
      />
      <.input_with_label
        field={@form[:password_confirmation]}
        label={dgettext("auth", "Confirm password")}
        autocomplete="new-password"
        type="password"
      />
      <.field_errors field={@form[:invitation_id]} show_untouched={true} />
      <.button type="submit" class="w-full">
        {dgettext("auth", "Create account")}
      </.button>
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
