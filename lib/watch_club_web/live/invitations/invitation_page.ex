defmodule WatchClubWeb.Invitations.InvitationPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Accounts.RegistrationForm
  import WatchClubWeb.Components.Accounts.SignInForm

  @impl true
  def render(
        %{invitation: %Invitation{}, current_user: nil, form: %Phoenix.HTML.Form{}} = assigns
      ) do
    title =
      case assigns.invitation.name do
        nil -> dgettext("invitations", "Hello!")
        name -> dgettext("invitations", "Hello %{name}!", name: name)
      end

    assigns = assigns |> assign(:title, title)

    ~H"""
    <Layouts.centered_card flash={@flash} title={@title}>
      <.stack space="related">
        <p>
          <.invitation_intro invitation={@invitation} />
        </p>
        <p>{dgettext("invitations", "Create an account or sign-in to accept the invitation.")}</p>
      </.stack>
      <.segmented_control aria-label={dgettext("invitations", "Invitation action")}>
        <:item
          id="invitation-register-tab"
          patch={~p"/invitations/#{@invitation.id}"}
          selected={@action == :register}
        >
          {dgettext("auth", "Create account")}
        </:item>
        <:item
          id="invitation-sign-in-tab"
          patch={~p"/invitations/#{@invitation.id}?action=sign_in"}
          selected={@action == :sign_in}
        >
          {dgettext("auth", "Sign in")}
        </:item>
      </.segmented_control>
      <.alert :if={@user_exists?} variant="info">
        <:icon><Lucideicons.info /></:icon>
        {dgettext("invitations", "Looks like you already have an account! Please login instead.")}
      </.alert>
      <.registration_form
        :if={@action == :register}
        id="invitation-registration-form"
        form={@form}
        change="validate_registration"
        submit="submit_registration"
      />
      <.sign_in_form
        :if={@action == :sign_in}
        id="invitation-sign-in-form"
        form={@form}
        change="validate_sign_in"
        submit="submit_sign_in"
      />
    </Layouts.centered_card>
    """
  end

  def render(%{invitation: %Invitation{}, current_user: %User{}} = assigns) do
    ~H"""
    <Layouts.centered_card
      flash={@flash}
      title={dgettext("invitations", "Hello %{name}!", name: @current_user.username)}
    >
      <.stack space="related">
        <p>
          <.invitation_intro invitation={@invitation} />
        </p>
        <p>{dgettext("invitations", "Create an account or sign-in to accept the invitation.")}</p>
      </.stack>
      <.inline class="justify-end">
        <.button id="accept-invitation-button" phx-click="accept_invitation">
          {dgettext("invitations", "Accept Invitation")}
        </.button>
      </.inline>
    </Layouts.centered_card>
    """
  end

  def render(assigns), do: ~H""

  attr :invitation, Invitation, required: true

  defp invitation_intro(%{invitation: %Invitation{inviter: %User{}}} = assigns) do
    ~H"""
    {raw(
      dgettext("invitations", "%{inviter} is inviting you to join %{club_name} on watch.club",
        inviter: gtbold(@invitation.inviter.username),
        club_name: gtbold(@invitation.club.name)
      )
    )}
    """
  end

  defp invitation_intro(assigns) do
    ~H"""
    {raw(
      dgettext("invitations", "You are invited to join %{club_name} on watch.club",
        club_name: gtbold(@invitation.club.name)
      )
    )}
    """
  end

  @impl true
  def mount(%{"invitation_id" => invitation_id}, session, socket) do
    # Make sure the invitation belongs to the current user is logged in
    case Clubs.view_invitation(invitation_id, actor: socket.assigns.current_user) do
      {:ok, invitation} ->
        locale = WatchClubWeb.Plugs.BrowserLocale.get(session)
        {:ok, socket |> assign(:invitation, invitation) |> assign(:locale, locale)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           dgettext("invitations", "The invitation you were trying to access does not exist")
         )
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

    %{invitation: %{id: invitation_id}, locale: locale} = socket.assigns

    form =
      case action do
        :sign_in ->
          Accounts.form_to_sign_in(sign_in_form_opts(invitation_id))

        :register ->
          Accounts.form_to_register_with_password(registration_form_opts(locale, invitation_id))
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
         |> put_flash(
           :success,
           dgettext("invitations", "You joined %{club_name}", club_name: invitation.club.name)
         )
         |> redirect(to: ~p"/")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           dgettext("invitations", "Couldn't join %{club_name}, try again later",
             club_name: invitation.club.name
           )
         )}
    end
  end

  def handle_event("validate_registration", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_registration", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        %{invitation: invitation} = socket.assigns

        socket =
          socket
          |> put_flash(
            :success,
            dgettext("invitations", "You joined %{club_name}", club_name: invitation.club.name)
          )
          |> redirect(
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("validate_sign_in", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit_sign_in", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params, read_one?: true) do
      {:ok, user} ->
        %{invitation: invitation} = socket.assigns

        socket =
          socket
          |> put_flash(
            :success,
            dgettext("invitations", "You joined %{club_name}", club_name: invitation.club.name)
          )
          |> redirect(
            to: ~p"/auth/user/password/sign_in_with_token?token=#{user.__metadata__.token}"
          )

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
