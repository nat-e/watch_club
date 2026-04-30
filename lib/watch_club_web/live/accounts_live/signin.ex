defmodule WatchClubWeb.AccountsLive.Signin do
  require Logger
  use WatchClubWeb, :live_view

  alias Ash.Error.Query.Required
  alias WatchClub.{Accounts, Clubs}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash}>
      <.separator orientation="vertical" />
      <.alert :if={@invitation} variant="secondary">
        <:icon><Lucideicons.info /></:icon>
        <span>
          Hello <span class="font-semibold">{@invitation.email}</span>
          ! <br /> Login to your account to accept your invitation.
        </span>
      </.alert>
      <.alert :if={@user_exists} variant="secondary">
        <:icon><Lucideicons.info /></:icon>
        Looks like you already have an account! Please login instead.
      </.alert>
      <.form
        for={@form}
        id="signin-form"
        phx-change="validate"
        phx-submit="submit"
        class="flex flex-col gap-6"
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
        <.button type="submit" phx-disable-with="Signing in..." class="w-full">
          Sign in
        </.button>
      </.form>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = Accounts.form_to_sign_in(form_opts())
    {:ok, socket |> assign(form: to_form(form))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket |> assign(user_exists: !!params["user_exists"]) |> assign_invitation(params)}
  end

  defp assign_invitation(socket, %{"invitation_id" => invitation_id}) do
    actor = socket.assigns.current_user

    with {:ok, uuid} <- Ecto.UUID.cast(invitation_id),
         {:ok, invitation} <- Clubs.view_invitation(uuid, actor: actor) do
      form =
        socket.assigns.form
        |> AshPhoenix.Form.update_params(&Map.put(&1, "invitation_id", invitation.id))

      socket |> assign(invitation: invitation) |> assign(form: form)
    else
      _ -> socket |> assign_invitation(%{})
    end
  end

  defp assign_invitation(socket, _params), do: assign(socket, invitation: nil)

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
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

  defp form_opts do
    [
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
