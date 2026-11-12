defmodule WatchClubWeb.Accounts.SetupPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={dgettext("auth", "Welcome to Watch Club!")}>
      <.stack space="related" class="text-text-muted">
        <p>
          {dgettext(
            "auth",
            "Create the administrator account. You'll use it to manage Watch Club and invite your friends."
          )}
        </p>
        <p>
          {dgettext(
            "auth",
            "Keep it to yourself: your friends get their own accounts through invitations."
          )}
        </p>
      </.stack>
      <.form
        for={@form}
        id="setup-form"
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
        <.field_errors field={@form[:invitation_code]} show_untouched={true} />
        <:action>
          <.button id="setup-form-submit-button" type="submit" class="w-full">
            {dgettext("auth", "Create account")}
          </.button>
        </:action>
      </.form>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    locale = WatchClubWeb.Plugs.BrowserLocale.get(session)

    form =
      Accounts.form_to_create_administrator(
        prepare_params: fn params, _ -> Map.put(params, :locale, locale) end,
        context: %{token_type: :sign_in}
      )

    {:ok, socket |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate_registration", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("submit_registration", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:success, dgettext("auth", "Administrator created"))
          |> redirect(
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
