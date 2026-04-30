defmodule WatchClubWeb.AccountsLive.Setup do
  require Logger
  use WatchClubWeb, :live_view

  alias Ash.Error.Changes.{InvalidAttribute, Required}
  alias WatchClub.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash}>
      <.form
        for={@form}
        id="setup-form"
        phx-change="validate"
        phx-submit="submit"
        class="flex flex-col gap-6"
      >
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
          <.label field={@form[:email]}>Email</.label>
          <.input field={@form[:email]} type="email" autocomplete="email" phx-debounce="blur" />
          <.field_errors field={@form[:email]} />
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
        <div class="flex flex-col gap-2">
          <.label field={@form[:password_confirmation]}>Confirm password</.label>
          <.input
            field={@form[:password_confirmation]}
            type="password"
            autocomplete="new-password"
            phx-debounce="blur"
          />
          <.field_errors field={@form[:password_confirmation]} />
        </div>
        <.button type="submit" phx-disable-with="Creating account..." class="w-full">
          Create account
        </.button>
      </.form>
    </Layouts.centered_card>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = Accounts.form_to_create_administrator(form_opts())
    {:ok, socket |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _} ->
        socket =
          socket |> put_flash(:success, "Administrator created") |> push_navigate(to: ~p"/")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp form_opts do
    [
      transform_errors: fn
        _, %Required{field: :username} ->
          {:username, "You must define a username", []}

        _, %InvalidAttribute{field: :username, vars: [min: min]} ->
          {:username, "Username must be at least %{min} characters", min: min}

        _, %InvalidAttribute{field: :username, vars: [max: max]} ->
          {:username, "Username cannot be longer than %{max} characters", max: max}

        _, %Required{field: :email} ->
          {:email, "You must define an email", []}

        _, %InvalidAttribute{field: :email} ->
          {:email, "Your email is not valid", []}

        _, %Required{field: :password} ->
          {:password, "You must define a password", []}

        _, %InvalidAttribute{field: :password, vars: [min: min]} ->
          {:password, "Password must be at least %{min} characters", min: min}

        _, %InvalidAttribute{field: :password, vars: [max: max]} ->
          {:password, "Password cannot be longer than %{max} characters", max: max}

        _, %_{field: :password_confirmation} ->
          {:password_confirmation, "Passwords do not match", []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
