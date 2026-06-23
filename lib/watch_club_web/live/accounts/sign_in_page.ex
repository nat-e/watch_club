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
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form =
      Accounts.form_to_sign_in(
        context: %{token_type: :sign_in},
        transform_errors: fn
          _, %AshAuthentication.Errors.AuthenticationFailed{} ->
            {:password, dgettext("errors", "Your username or password is invalid"), []}

          _, err ->
            err
        end
      )

    {:ok, socket |> assign(form: to_form(form))}
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
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )
        }

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
