defmodule WatchClubWeb.Components.Modals do
  alias WatchClubWeb.Modals.ViewInvitationLink
  use WatchClubWeb, :component

  attr :current_url, Url, required: true
  attr :current_user, User, required: true

  def modals_portal(
        %{
          current_url: %Url{params: %{"create_invitation" => club_id}},
          current_user: %User{} = current_user
        } = assigns
      ) do
    case Enum.find(current_user.memberships, fn m -> m.club.id == club_id end) do
      nil ->
        # Invalid club ID
        ~H""

      membership ->
        assigns = assigns |> assign(:club, membership.club)

        ~H"""
        <.modal
          open={true}
          on_close={close_modal(@current_url, Modals.CreateInvitation.modal_name())}
        >
          <.live_component
            id="invite_club_members_modal"
            module={Modals.CreateInvitation}
            club={@club}
            current_user={@current_user}
            current_url={@current_url}
          />
        </.modal>
        """
    end
  end

  def modals_portal(
        %{
          current_url: %Url{
            authority: authority,
            scheme: scheme,
            params: %{"view_invitation_link" => invitation_id}
          }
        } = assigns
      ) do
    assigns =
      assigns
      |> assign(
        :invitation_link,
        scheme <> "://" <> authority <> ~p"/invitations/#{invitation_id}"
      )

    ~H"""
    <.modal
      open={true}
      on_close={close_modal(@current_url, ViewInvitationLink.modal_name())}
    >
      <.live_component
        id="view_invitation_link_modal"
        module={Modals.ViewInvitationLink}
        invitation_link={@invitation_link}
      />
    </.modal>
    """
  end

  def modals_portal(
        %{
          current_url: %Url{params: %{"create_club" => "true"}},
          current_user: %User{}
        } = assigns
      ) do
    ~H"""
    <.modal
      open={true}
      on_close={close_modal(@current_url, Modals.CreateClub.modal_name())}
    >
      <.live_component
        id="create_club_modal"
        module={Modals.CreateClub}
        current_user={@current_user}
      />
    </.modal>
    """
  end

  def modals_portal(
        %{
          current_url: %Url{params: %{"delete_club" => club_id}},
          current_user: %User{} = current_user
        } = assigns
      ) do
    case Enum.find(current_user.memberships, fn m -> m.club.id == club_id end) do
      nil ->
        # Invalid club ID
        ~H""

      membership ->
        assigns = assigns |> assign(:club, membership.club)

        ~H"""
        <.modal
          open={true}
          on_close={close_modal(@current_url, Modals.DeleteClub.modal_name())}
        >
          <.live_component
            id="delete_club_modal"
            module={Modals.DeleteClub}
            club={@club}
            current_user={@current_user}
          />
        </.modal>
        """
    end
  end

  def modals_portal(
        %{
          current_url: %Url{},
          current_user: %User{}
        } = assigns
      ),
      do: ~H""

  defp close_modal(current_url, param) do
    JS.patch(
      current_url
      |> Url.remove_param(param)
      |> Url.to_url()
    )
  end
end
