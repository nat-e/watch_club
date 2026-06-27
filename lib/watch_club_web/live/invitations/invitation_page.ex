defmodule WatchClubWeb.Invitations.InvitationPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(
        %{invitation: %InvitationCode{status: :active}, form: %Phoenix.HTML.Form{}} = assigns
      ) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={dgettext("invitations", "Welcome!")}>
      <.stack space="related">
        <p>
          {dgettext("invitations", "You are invited to create an account on %{name}!",
            name: @instance_settings.name
          )}
        </p>
      </.stack>
      <.form
        for={@form}
        id="invitation-registration-form"
        phx-change="validate_registration"
        phx-submit="submit_registration"
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
        <.field
          field={@form[:invitation_code]}
          label={dgettext("auth", "Invitation Code")}
          readonly={true}
          type="text"
        />
        <:action>
          <.button id="invitation-registration-form-submit-button" type="submit" class="w-full">
            {dgettext("auth", "Create account")}
          </.button>
        </:action>
      </.form>
    </Layouts.centered_card>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.centered_card
      flash={@flash}
      title={dgettext("invitations", "This invitation is no longer available")}
    >
      <p>
        {dgettext("invitations", "Ask the person who invited you for a new link.")}
      </p>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(%{"code" => code}, session, socket) do
    case Accounts.view_invitation(code, actor: socket.assigns.current_user) do
      {:ok, invitation} ->
        locale = WatchClubWeb.Plugs.BrowserLocale.get(session)

        form =
          Accounts.form_to_register_with_password(
            params: %{"invitation_code" => code},
            prepare_params: fn params, _ -> Map.put(params, :locale, locale) end,
            context: %{token_type: :sign_in}
          )

        {:ok,
         socket
         |> assign(:invitation, invitation)
         |> assign(:form, to_form(form))}

      {:error, _} ->
        {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate_registration", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_registration", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        socket =
          socket
          |> redirect(
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
