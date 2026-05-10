defmodule WatchClubWeb.AccountsLive.Setup do
  require Logger
  use WatchClubWeb, :live_view

  alias WatchClub.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={dgettext("auth", "Welcome to watch.club!")}>
      <div class="flex flex-col text-muted-foreground gap-2">
        <p>
          {dgettext(
            "auth",
            "To configure your instance, you need to setup a unique administrator account."
          )}
        </p>
        <p>
          {dgettext(
            "auth",
            "Do not share the credentials of this account, you will be able to invite other users later."
          )}
        </p>
      </div>
      <.registration_form form={@form} />
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    locale = WatchClubWeb.Plugs.BrowserLocale.get(session)
    form = Accounts.form_to_create_administrator(registration_form_opts(locale))
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
