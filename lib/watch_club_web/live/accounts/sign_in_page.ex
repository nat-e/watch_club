defmodule WatchClubWeb.Accounts.SignInPage do
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={dgettext("auth", "Welcome back!")}>
      <.form
        for={@form}
        id="signin-form"
        phx-change="validate_sign_in"
        phx-submit="submit_sign_in"
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
        <:action>
          <.button id="signin-form-submit-button" type="submit" class="w-full">
            {dgettext("auth", "Sign in")}
          </.button>
        </:action>
      </.form>
      <p class="text-sm text-text-muted">
        {dgettext("auth", "Forgot your password? Ask the administrator for a reset link.")}
      </p>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    form =
      Accounts.form_to_sign_in(
        context: %{token_type: :sign_in},
        transform_errors: fn
          _query, %AshAuthentication.Errors.AuthenticationFailed{} ->
            [{:password, dgettext_noop("errors", "Wrong username or password"), []}]

          _query, error ->
            error
        end
      )

    # The page to open after sign-in, set when a page that needs a user redirects here
    {:ok, socket |> assign(form: to_form(form), return_to: params["return_to"] || ~p"/")}
  end

  @impl true
  def handle_event("validate_sign_in", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("submit_sign_in", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params, read_one?: true) do
      {:ok, user} ->
        {
          :noreply,
          socket
          |> redirect(
            to:
              ~p"/auth/user/password/sign_in_with_token?#{[token: user.__metadata__.token, return_to: socket.assigns.return_to]}"
          )
        }

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
