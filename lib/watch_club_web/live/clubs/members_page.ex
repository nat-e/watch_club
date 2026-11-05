defmodule WatchClubWeb.Clubs.MembersPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Live.Clubs.Members.{AddMembersModal, MembersTable, RemoveMemberModal}

  on_mount {WatchClubWeb.Hooks.LoadClub, true}

  @impl true
  def render(%{club: %Club{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      space="section"
      class="max-w-layout-page"
      title={dgettext("clubs", "Members")}
    >
      <:parent navigate={~p"/clubs/#{@club.id}"} label={@club.name} />
      <.page_description text={
        dgettext("clubs", "Manage %{club_name}'s members.", club_name: @club.name)
      } />

      <.stack space="group">
        <div class="flex justify-end">
          <.button
            id="new-invitation-button"
            variant="primary"
            phx-click="open_add_members_modal"
            emphasis={true}
            class="w-fit"
          >
            <:icon><Lucideicons.plus /></:icon>
            {dgettext("clubs", "Add members")}
          </.button>
        </div>
        <.members_table
          memberships={@memberships}
          current_user={@current_user}
          current_url={@current_url}
        />
      </.stack>
      <.add_members_modal
        :if={@show_add_members_modal}
        users={@users}
        existing_memberships={@memberships}
      />
      <.remove_member_modal :if={@membership_to_remove} membership={@membership_to_remove} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> close_modals()}
  end

  @impl true
  def handle_params(%{"club_id" => club_id}, _uri, socket) do
    WatchClub.PubSub.subscribe_if_connected(socket, [
      "club:#{club_id}",
      "memberships:club:#{club_id}"
    ])

    {:noreply, socket |> reload_club_members()}
  end

  @impl true
  def handle_info(%Notification{resource: Club}, socket) do
    {:noreply, socket |> reload_club()}
  end

  def handle_info(%Notification{resource: ClubMembership}, socket) do
    {:noreply, socket |> reload_club_members()}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_add_members_modal", _params, socket) do
    users = Accounts.list_users!(actor: socket.assigns.current_user)
    {:noreply, socket |> assign(:show_add_members_modal, true) |> assign(:users, users)}
  end

  def handle_event("submit_add_members", params, socket) do
    case params["user_ids"] do
      user_ids when is_list(user_ids) ->
        Clubs.add_club_members!(socket.assigns.club, user_ids, actor: socket.assigns.current_user)

        {:noreply,
         socket |> close_modals() |> put_flash(:success, dgettext("clubs", "Users added to club"))}

      nil ->
        {:noreply, socket |> close_modals()}
    end
  end

  def handle_event("open_remove_member_modal", %{"membership_id" => membership_id}, socket) do
    {:noreply,
     socket
     |> assign(
       :membership_to_remove,
       socket.assigns.memberships |> Enum.find(&(&1.id == membership_id))
     )}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, socket |> close_modals()}
  end

  def handle_event("confirm_remove_member", _params, socket) do
    %{membership_to_remove: %Membership{} = membership, current_user: %User{} = user} =
      socket.assigns

    Clubs.remove_from_club!(membership, actor: user)

    {:noreply,
     socket
     |> close_modals()
     |> put_flash(:success, dgettext("clubs", "Member removed"))}
  end

  defp reload_club(socket) do
    # We need to handle error case since Ash.NotFound is expected when PubSub is triggered by Club deletion
    case Clubs.get_club_by_id(socket.assigns.club.id, actor: socket.assigns.current_user) do
      {:ok, club} -> socket |> assign(club: club)
      {:error, _error} -> socket |> redirect_home()
    end
  end

  defp reload_club_members(socket) do
    club = Ash.load!(socket.assigns.club, [:memberships], actor: socket.assigns.current_user)
    socket |> assign(memberships: club.memberships)
  end

  defp close_modals(socket) do
    socket |> assign(membership_to_remove: nil, show_add_members_modal: false, users: nil)
  end

  defp redirect_home(socket) do
    socket
    |> put_flash(:error, dgettext("clubs", "The page you were looking for does not exist"))
    |> push_navigate(to: ~p"/")
  end
end
