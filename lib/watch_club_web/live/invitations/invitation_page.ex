defmodule WatchClubWeb.Invitations.InvitationPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(
        %{invitation: %InvitationCode{status: :active}, form: %Phoenix.HTML.Form{}} = assigns
      ) do
    ~H"""
    <Layouts.centered_card
      flash={@flash}
      title={dgettext("invitations", "You're invited to %{name}", name: @instance_settings.name)}
    >
      <p>
        {dgettext(
          "invitations",
          "A private community for watching and discussing movies, TV shows and more with friends."
        )}
      </p>
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
        >
          <:hint>
            {dgettext("auth", "Your friends will see it. Use lowercase letters, numbers and _.")}
          </:hint>
        </.field>
        <.field
          field={@form[:password]}
          label={dgettext("auth", "Password")}
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
        <input
          type="hidden"
          name={@form[:invitation_code].name}
          value={@form[:invitation_code].value}
        />
        <.field_errors field={@form[:invitation_code]} show_untouched={true} />
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
      title={dgettext("invitations", "This invitation no longer works")}
    >
      <p>
        {dgettext("invitations", "Ask the person who invited you for a new link.")}
      </p>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(params, session, socket) do
    case Accounts.view_invitation(params["code"], actor: socket.assigns.current_user) do
      {:ok, invitation} ->
        locale = WatchClubWeb.Plugs.BrowserLocale.get(session)

        form =
          Accounts.form_to_register_with_password(
            params: %{"invitation_code" => invitation.code},
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
