defmodule WatchClubWeb.Accounts.ResetPasswordPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(%{form: nil} = assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={dgettext("auth", "This link no longer works")}>
      <p>
        {dgettext("auth", "Reset links expire after 3 days. Ask the administrator for a new one.")}
      </p>
      <.button id="back-to-sign-in-button" navigate={~p"/sign-in"} class="w-full">
        {dgettext("auth", "Back to sign in")}
      </.button>
    </Layouts.centered_card>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={dgettext("auth", "Choose a new password")}>
      <.form
        for={@form}
        id="reset-password-form"
        phx-change="validate_reset_password"
        phx-submit="submit_reset_password"
        phx-mounted={JS.focus_first()}
      >
        <.field
          field={@form[:password]}
          label={dgettext("auth", "New password")}
          autocomplete="new-password"
          type="password"
        >
          <:hint>{dgettext("auth", "At least %{min} characters.", min: 8)}</:hint>
        </.field>
        <.field
          field={@form[:password_confirmation]}
          label={dgettext("auth", "Confirm password")}
          autocomplete="new-password"
          type="password"
        />
        <.field_errors field={@form[:reset_token]} show_untouched={true} />
        <:action>
          <.button id="reset-password-form-submit-button" type="submit" class="w-full">
            {dgettext("auth", "Save password")}
          </.button>
        </:action>
      </.form>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    # The form can only be built from a valid token since the reset action operates
    # on the user identified by it. A nil form means the link is not usable.
    form =
      with token when is_binary(token) <- params["token"],
           {:ok, %{"sub" => subject}, _resource} <- AshAuthentication.Jwt.verify(token, User),
           {:ok, user} <- AshAuthentication.subject_to_user(subject, User) do
        Accounts.form_to_reset_password_with_token(user,
          context: %{token_type: :sign_in},
          prepare_params: fn params, _ -> Map.put(params, "reset_token", token) end
        )
        |> to_form()
      else
        _ -> nil
      end

    {:ok, socket |> assign(form: form)}
  end

  @impl true
  def handle_event("validate_reset_password", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("submit_reset_password", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        {
          :noreply,
          socket
          |> put_flash(:success, dgettext("auth", "New password saved."))
          |> redirect(
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )
        }

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
