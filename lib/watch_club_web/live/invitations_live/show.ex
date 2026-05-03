defmodule WatchClubWeb.InvitationsLive.Show do
  use WatchClubWeb, :live_view

  @impl true
  def render(
        %{invitation: %Invitation{}, current_user: nil, form: %Phoenix.HTML.Form{}} = assigns
      ) do
    assigns =
      assigns
      |> assign(
        :title,
        ["Hello", assigns.invitation.name, "!"] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
      )

    ~H"""
    <Layouts.centered_card flash={@flash} title={@title}>
      <div>
        <p>
          <span class="font-bold">{@invitation.inviter.username}</span>
          is inviting you to join <span class="font-bold">{@invitation.club.name}</span>
          on watch.club.
        </p>
        <p>Create an account or sign-in to accept the invitation.</p>
      </div>
      <.alert :if={@user_exists?} variant="secondary">
        <:icon><Lucideicons.info /></:icon>
        Looks like you already have an account! Please login instead.
      </.alert>
      <.registration_form :if={@action == :register} form={@form} />
      <.sign_in_form :if={@action == :sign_in} form={@form} />
    </Layouts.centered_card>
    """
  end

  def render(%{invitation: %Invitation{}, current_user: %User{}} = assigns) do
    ~H"""
    <Layouts.centered_card flash={@flash} title={"Hello #{@current_user.username}"}>
      <div>
        <p>
          <span class="font-bold">{@invitation.inviter.username}</span>
          is inviting you to join <span class="font-bold">{@invitation.club.name}</span>
          on watch.club.
        </p>
        <p>Create an account or sign-in to accept the invitation.</p>
      </div>
      <div class="flex flex-row items-center justify-end">
        <.button type="submit" variant="default" phx-click="accept_invitation">
          Accept Invitation
        </.button>
      </div>
    </Layouts.centered_card>
    """
  end

  def render(assigns), do: ~H""

  @impl true
  def mount(%{"invitation_id" => invitation_id}, _session, socket) do
    # Make sure the invitation belongs to the current user is logged in
    case Clubs.view_invitation(invitation_id, actor: socket.assigns.current_user) do
      {:ok, invitation} ->
        {:ok, socket |> assign(:invitation, invitation)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "The invitation you were trying to access does not exist")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    action =
      if params["action"] == "sign_in" do
        :sign_in
      else
        :register
      end

    invitation_id = socket.assigns.invitation.id

    form =
      case action do
        :sign_in ->
          Accounts.form_to_sign_in(sign_in_form_opts(invitation_id))

        :register ->
          Accounts.form_to_register_with_password(registration_form_opts(invitation_id))
      end

    {:noreply,
     socket
     |> assign(:user_exists?, !!params["user_exists"])
     |> assign(:action, action)
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event(
        "accept_invitation",
        _params,
        %{assigns: %{current_user: user, invitation: invitation}} = socket
      ) do
    case Clubs.accept_invitation(invitation, actor: user) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> put_flash(:success, "You joined #{invitation.club.name}")
         |> redirect(to: ~p"/")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Couldn't join #{invitation.club.name}, try again later")}
    end
  end

  def handle_event("validate_registration", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_registration", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        socket =
          socket
          |> put_flash(:success, "Your account has been created")
          |> redirect(
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
