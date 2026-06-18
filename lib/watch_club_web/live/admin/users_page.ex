defmodule WatchClubWeb.Admin.UsersPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader

  import WatchClubWeb.Live.Admin.UsersPage.{
    CreateOrEditInvitationCodeModal,
    DeleteUserModal,
    DeleteInvitationCodeModal,
    InvitationCodesSection,
    UsersTable
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
    >
      <div class="mx-auto w-full min-w-0 max-w-layout-page">
        <.stack space="cluster">
          <.settings_header
            title={dgettext("admin_users", "Users")}
            description={
              dgettext(
                "admin_users",
                "Manage access to your WatchClub instance."
              )
            }
          />

          <.invitation_codes_section
            invitations={@invitations}
            current_user={@current_user}
            current_url={@current_url}
          />

          <.stack space="group">
            <div class="flex justify-end">
              <.button
                id="new-invitation-button"
                variant="primary"
                phx-click="open_create_invitation_code_modal"
                emphasis={true}
                class="w-fit"
              >
                <:icon><Lucideicons.plus /></:icon>
                {dgettext("admin_invitations", "Invite users")}
              </.button>
            </div>
            <.users_table users={@users} current_user={@current_user} />
          </.stack>
        </.stack>

        <.delete_user_modal :if={@user_to_delete} user={@user_to_delete} />

        <.create_invitation_code_modal
          :if={@invitation_form}
          form={@invitation_form}
          current_user={@current_user}
        />
        <.delete_invitation_code_modal
          :if={@invitation_code_to_delete}
          invitation={@invitation_code_to_delete}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    WatchClub.PubSub.subscribe_if_connected(socket, ["users", "invitation_codes"])

    {:ok,
     socket
     |> reload_invitation_codes()
     |> reload_users()
     |> close_modals()}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "users"}, socket) do
    {:noreply, socket |> reload_users()}
  end

  def handle_info(%Phoenix.Socket.Broadcast{topic: "invitation_codes"}, socket) do
    {:noreply, socket |> reload_invitation_codes()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_delete_user_modal", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:user_to_delete, Enum.find(socket.assigns.users, &(&1.id == id)))}
  end

  def handle_event("open_create_invitation_code_modal", _params, socket) do
    form =
      Accounts.form_to_create_invitation_code(
        actor: socket.assigns.current_user,
        params: %{
          # Initialize the form with a pre-generated 10 characters code
          code:
            :crypto.strong_rand_bytes(10)
            |> Base.encode32(padding: false)
        },
        prepare_params: fn params, _ ->
          # Unchecked checkbox groups submit no key at all
          Map.put_new(params, "club_ids", [])
        end
      )

    {:noreply, socket |> assign(:invitation_form, to_form(form))}
  end

  def handle_event(
        "open_edit_invitation_code_modal",
        %{"id" => invitation_code_id},
        socket
      ) do
    form =
      socket.assigns.invitations
      |> Enum.find(&(&1.id == invitation_code_id))
      |> Accounts.form_to_update_invitation_code(
        actor: socket.assigns.current_user,
        prepare_params: fn params, _ ->
          # Unchecked checkbox groups submit no key at all
          Map.put_new(params, "club_ids", [])
        end
      )

    {:noreply, socket |> assign(:invitation_form, to_form(form))}
  end

  def handle_event("validate_invitation_form", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.invitation_form, params)

    {:noreply, socket |> assign(:invitation_form, form)}
  end

  def handle_event("submit_invitation_form", %{"form" => params}, socket) do
    form = socket.assigns.invitation_form
    edit? = form.source.type == :update

    case AshPhoenix.Form.submit(socket.assigns.invitation_form,
           params: params,
           read_one?: true
         ) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> close_modals()
         |> put_flash(
           :success,
           (edit? && dgettext("admin_invitations", "Invitation updated")) ||
             dgettext("admin_invitations", "Invitation created")
         )}

      {:error, form} ->
        {:noreply, socket |> assign(:invitation_form, form)}
    end
  end

  def handle_event("open_delete_invitation_code_modal", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(
       :invitation_code_to_delete,
       Enum.find(socket.assigns.invitations, &(&1.id == id))
     )}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, socket |> close_modals()}
  end

  def handle_event("confirm_delete_user", _params, socket) do
    %{user_to_delete: %User{} = user, current_user: %User{} = current_user} = socket.assigns
    Accounts.destroy_user!(user, actor: current_user)

    {:noreply,
     socket
     |> close_modals()
     |> put_flash(:success, dgettext("admin_users", "User deleted"))}
  end

  def handle_event("invitation_link_copied", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, dgettext("admin_invitations", "Invitation link copied to clipboard"))}
  end

  def handle_event("confirm_delete_invitation_code", _params, socket) do
    %{
      invitation_code_to_delete: %InvitationCode{} = invitation,
      current_user: %User{} = current_user
    } =
      socket.assigns

    Accounts.delete_invitation_code!(invitation, actor: current_user)

    {:noreply,
     socket
     |> assign(:invitation_code_to_delete, nil)
     |> put_flash(:success, dgettext("admin_invitations", "Invitation code deleted"))}
  end

  defp close_modals(socket) do
    socket
    |> assign(:user_to_delete, nil)
    |> assign(:invitation_form, nil)
    |> assign(:invitation_to_share, nil)
    |> assign(:invitation_code_to_delete, nil)
  end

  defp reload_invitation_codes(socket) do
    socket
    |> assign(
      :invitations,
      Accounts.list_invitation_codes!(
        actor: socket.assigns.current_user,
        load: [:clubs],
        query: [filter: [status: :active]]
      )
    )
  end

  defp reload_users(socket) do
    socket
    |> assign(
      :users,
      Accounts.list_users!(%{},
        actor: socket.assigns.current_user,
        load: [memberships: [:club]],
        query: [sort: [inserted_at: :asc]]
      )
    )
  end
end
