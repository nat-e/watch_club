defmodule WatchClubWeb.AccountsLive.Signin do
  require Logger
  use WatchClubWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title="Welcome back!">
      <.sign_in_form form={@form} />
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = Accounts.form_to_sign_in(sign_in_form_opts())
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
