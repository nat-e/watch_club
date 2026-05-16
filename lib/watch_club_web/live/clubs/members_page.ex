defmodule WatchClubWeb.Clubs.MembersPage do
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Settings.SettingsHeader
  import WatchClubWeb.Components.Settings.SettingsSection

  @impl true
  def render(%{club: %Club{}} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      space="section"
      class="max-w-layout-page"
    >
      <.settings_header
        title={dgettext("clubs", "Members")}
        description={
          dgettext("clubs", "Manage %{club_name}'s members and invitations.", club_name: @club.name)
        }
      />

      <.settings_section
        title={dgettext("clubs", "Members and invitations")}
        description={
          dgettext(
            "clubs",
            "Review who can access the club and share one-time invitation links."
          )
        }
      >
        <:action>
          <.button phx-click="open_create_invitation_modal">
            <Lucideicons.plus />
            {dgettext("clubs", "Invite member")}
          </.button>
        </:action>

        <.table>
          <.table_header>
            <.table_row>
              <.table_head class="text-left">{dgettext("clubs", "User")}</.table_head>
              <.table_head>{dgettext("clubs", "Role")}</.table_head>
              <.table_head>{dgettext("clubs", "Member since")}</.table_head>
              <.table_head class="text-left">{dgettext("clubs", "Invited by")}</.table_head>
              <.table_head class="text-right"></.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <%!--
              Club memberships and invitations are intentionally low-cardinality,
              so a regular assign is simpler than LiveView streams here.
            --%>
            <.member_row
              :for={membership <- @club.memberships}
              membership={membership}
              current_url={@current_url}
              current_user={@current_user}
            />
            <.invitation_row
              :for={invitation <- @club.invitations}
              invitation={invitation}
              current_url={@current_url}
              current_user={@current_user}
            />
          </.table_body>
        </.table>
      </.settings_section>
      <.remove_member_modal :if={@membership_to_remove} membership={@membership_to_remove} />
      <.create_invitation_modal :if={@create_invitation_form} form={@create_invitation_form} />
      <.view_invitation_modal
        :if={@invitation_to_view}
        invitation={@invitation_to_view}
        current_url={@current_url}
      />
      <.destroy_invitation_modal :if={@invitation_to_destroy} />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_url={@current_url} current_user={@current_user}></Layouts.app>
    """
  end

  defp member_row(assigns) do
    ~H"""
    <.table_row>
      <.table_cell class="text-left">
        <.inline class="font-bold">
          <.avatar id={@membership.user.id} name={@membership.user.username} />
          {@membership.user.username}
        </.inline>
      </.table_cell>
      <.table_cell>
        <.role_badge role={@membership.role} />
      </.table_cell>
      <.table_cell>
        {WatchClubWeb.Helpers.Time.relative_from_now(@membership.inserted_at)}
      </.table_cell>
      <.table_cell class="text-left">
        <.inviter_label :if={@membership.invitation} inviter={@membership.invitation.inviter} />
      </.table_cell>
      <.table_cell class="text-right">
        <.dropdown_menu
          :if={@membership.user_id != @current_user.id}
          id={"member-actions-#{@membership.id}"}
        >
          <:trigger>
            <.button size="icon" variant="ghost">
              <Lucideicons.ellipsis_vertical />
            </.button>
          </:trigger>
          <.dropdown_menu_item
            :if={@membership.user_id != @current_user.id}
            variant="destructive"
            phx-click="open_remove_member_modal"
            phx-value-membership_id={@membership.id}
          >
            <Lucideicons.trash_2 />{dgettext("clubs", "Remove member")}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </.table_cell>
    </.table_row>
    """
  end

  defp invitation_row(assigns) do
    ~H"""
    <.table_row class="text-text-muted">
      <.table_cell class="text-left">
        <.inline class="font-bold italic">
          {@invitation.name}
        </.inline>
      </.table_cell>
      <.table_cell>
        <.invitation_status_badge invitation={@invitation} />
      </.table_cell>
      <.table_cell></.table_cell>
      <.table_cell class="text-left">
        <.inviter_label inviter={@invitation.inviter} />
      </.table_cell>
      <.table_cell class="text-right">
        <.dropdown_menu id={"invitation-actions-#{@invitation.id}"}>
          <:trigger>
            <.button size="icon" variant="ghost">
              <Lucideicons.ellipsis_vertical />
            </.button>
          </:trigger>
          <.dropdown_menu_item
            phx-click="open_view_invitation_modal"
            phx-value-invitation_id={@invitation.id}
          >
            <Lucideicons.user />{dgettext("clubs", "Share Invitation")}
          </.dropdown_menu_item>
          <.dropdown_menu_item
            variant="destructive"
            phx-click="open_destroy_invitation_modal"
            phx-value-invitation_id={@invitation.id}
          >
            <Lucideicons.trash_2 />{dgettext("clubs", "Delete invitation")}
          </.dropdown_menu_item>
        </.dropdown_menu>
      </.table_cell>
    </.table_row>
    """
  end

  attr :inviter, :any, required: true

  defp inviter_label(%{inviter: %User{}} = assigns) do
    ~H"""
    <.inline class="font-bold">
      <.avatar id={@inviter.id} name={@inviter.username} />
      {@inviter.username}
    </.inline>
    """
  end

  defp inviter_label(assigns) do
    ~H"""
    <.inline class="font-bold italic text-text-muted">
      {dgettext("clubs", "Deleted user")}
    </.inline>
    """
  end

  attr :role, :atom, required: true

  defp role_badge(%{role: :admin} = assigns) do
    ~H"""
    <.badge variant="accent">Admin</.badge>
    """
  end

  defp role_badge(%{role: :member} = assigns) do
    ~H"""
    <.badge variant="secondary">Member</.badge>
    """
  end

  attr :invitation, Invitation, required: true

  defp invitation_status_badge(%{invitation: %Invitation{accepted?: true}} = assigns) do
    ~H"""
    <.badge variant="success">Accepted</.badge>
    """
  end

  defp invitation_status_badge(%{invitation: %Invitation{expired?: false}} = assigns) do
    ~H"""
    <.badge variant="accent">Invited</.badge>
    """
  end

  defp invitation_status_badge(%{invitation: %Invitation{}} = assigns) do
    ~H"""
    <.badge variant="muted">Expired</.badge>
    """
  end

  defp remove_member_modal(assigns) do
    ~H"""
    <.modal id="remove-member-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Remove club member")}</:title>
      <p>
        {raw(
          dgettext(
            "clubs",
            "Are you sure you want to remove %{username}?",
            username: gtbold(@membership.user.username)
          )
        )}
      </p>
      <p>{dgettext("clubs", "They won't be able to join back without being re-invited.")}</p>
      <:footer>
        <.button type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>

        <.button variant="danger" phx-click="confirm_remove_member">
          {dgettext("clubs", "Remove")}
        </.button>
      </:footer>
    </.modal>
    """
  end

  defp destroy_invitation_modal(assigns) do
    ~H"""
    <.modal id="destroy-invitation-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Delete invitation")}</:title>
      <p>
        {dgettext("clubs", "Are you sure you want to delete this invitation?")}
      </p>
      <p>
        {dgettext("clubs", "The invitation link will not be active anymore.")}
      </p>
      <:footer>
        <.button type="button" variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>

        <.button variant="danger" phx-click="confirm_destroy_invitation">
          {dgettext("default", "Delete")}
        </.button>
      </:footer>
    </.modal>
    """
  end

  defp create_invitation_modal(assigns) do
    ~H"""
    <.modal id="create-invitation-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Create invitation")}</:title>
      <:description>
        {dgettext("clubs", "Create a shareable invitation link to join the club")}
      </:description>
      <.form
        :if={@form}
        for={@form}
        id="create_invitation_form"
        phx-change="validate_create_invitation"
        phx-submit="submit_create_invitation"
      >
        <.field
          field={@form[:name]}
          label={dgettext("clubs", "Name")}
          type="text"
          autocomplete="name"
        />
        <.field field={@form[:role]} label={dgettext("clubs", "Club Role")}>
          <:control>
            <.radio_group field={@form[:role]} class="grid-cols-1 sm:grid-cols-2">
              <:item
                value="member"
                class="group/radio-card grid cursor-pointer grid-cols-[1fr_auto] items-center gap-related rounded-control border border-border bg-surface-inset p-group transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected [&>[data-slot=radio-group-item]]:sr-only"
              >
                <span class="font-medium">{dgettext("clubs", "Member")}</span>
                <Lucideicons.check class="size-icon-sm text-primary opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
              </:item>
              <:item
                value="admin"
                class="group/radio-card grid cursor-pointer grid-cols-[1fr_auto] items-center gap-related rounded-control border border-border bg-surface-inset p-group transition-colors hover:bg-surface-hover has-[:checked]:border-primary has-[:checked]:bg-surface-selected [&>[data-slot=radio-group-item]]:sr-only"
              >
                <span class="font-medium">{dgettext("clubs", "Admin")}</span>
                <Lucideicons.check class="size-icon-sm text-primary opacity-0 transition-opacity group-has-[:checked]/radio-card:opacity-100" />
              </:item>
            </.radio_group>
          </:control>
        </.field>
        <:action>
          <.button type="submit" class="w-full">
            {dgettext("clubs", "Create invitation")}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end

  defp view_invitation_modal(
         %{
           current_url: %Url{
             authority: authority,
             scheme: scheme
           },
           invitation: %Invitation{id: invitation_id}
         } = assigns
       ) do
    assigns =
      assigns
      |> assign(
        :invitation_link,
        scheme <> "://" <> authority <> ~p"/invitations/#{invitation_id}"
      )

    ~H"""
    <.modal id="view-invitation-modal" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Share invitation")}</:title>
      <:description>
        {dgettext(
          "clubs",
          "Copy and share the invitation link below with anyone. It is only usable once."
        )}
      </:description>
      <.stack space="group" class="items-center">
        <.alert variant="accent" class="items-center">
          <span id="invitation_link">{@invitation_link}</span>
          <:action>
            <.button
              variant="accent"
              phx-click={
                JS.dispatch("wc:copy_to_clipboard", to: "#invitation_link")
                |> JS.push("invitation_link_copied")
              }
            >
              <Lucideicons.copy />
            </.button>
          </:action>
        </.alert>
        <.button type="button" variant="secondary" class="w-full" data-modal-close>
          {dgettext("default", "Close")}
        </.button>
      </.stack>
    </.modal>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:membership_to_remove, nil)
     |> assign(:invitation_to_destroy, nil)
     |> assign(:create_invitation_form, nil)
     |> assign(:invitation_to_view, nil)}
  end

  @impl true
  def handle_params(%{"club_id" => club_id}, _uri, socket) do
    case Clubs.get_members_and_invitations_by_id(club_id, actor: socket.assigns.current_user) do
      {:ok, club} ->
        {:noreply, socket |> assign(:club, club)}

      {:error, %Ash.Error.Query.NotFound{}} ->
        not_found(socket)

      {:error, %Ash.Error.Invalid{}} ->
        not_found(socket)

      {:error, %Ash.Error.Forbidden{}} ->
        not_found(socket)

      {:error, error} ->
        Logger.warning("Unexpected error loading members: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_remove_member_modal", %{"membership_id" => membership_id}, socket) do
    %Membership{} =
      membership = Enum.find(socket.assigns.club.memberships, fn i -> i.id == membership_id end)

    {:noreply, socket |> assign(:membership_to_remove, membership)}
  end

  def handle_event("open_destroy_invitation_modal", %{"invitation_id" => invitation_id}, socket) do
    %Invitation{} =
      invitation = Enum.find(socket.assigns.club.invitations, fn i -> i.id == invitation_id end)

    {:noreply, socket |> assign(:invitation_to_destroy, invitation)}
  end

  def handle_event("open_create_invitation_modal", _params, socket) do
    %{current_user: current_user, club: club} = socket.assigns

    form =
      Clubs.form_to_create_invitation(
        actor: current_user,
        # Default role for the member
        params: %{role: :member},
        # Append club_id before validate/submit without requiring a hidden field
        prepare_params: fn params, _ -> Map.put(params, :club_id, club.id) end,
        transform_errors: fn
          _, %Ash.Error.Changes.Required{field: :role} ->
            {:role, "You must select a role", []}

          _, err ->
            Logger.warning("Unexpected form error: #{inspect(err)}")
            err
        end
      )

    {:noreply, socket |> assign(:create_invitation_form, to_form(form))}
  end

  def handle_event("validate_create_invitation", %{"form" => params}, socket) do
    {:noreply,
     assign(socket,
       create_invitation_form:
         AshPhoenix.Form.validate(socket.assigns.create_invitation_form, params)
     )}
  end

  def handle_event("submit_create_invitation", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.create_invitation_form,
           params: params,
           read_one?: true
         ) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> assign(:create_invitation_form, nil)
         |> assign(:invitation_to_view, invitation)
         |> put_flash(:success, dgettext("clubs", "Invitation created"))}

      {:error, form} ->
        {:noreply, assign(socket, create_invitation_form: form)}
    end
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply,
     socket
     |> assign(:membership_to_remove, nil)
     |> assign(:invitation_to_destroy, nil)
     |> assign(:create_invitation_form, nil)
     |> assign(:invitation_to_view, nil)}
  end

  def handle_event("confirm_remove_member", _params, socket) do
    %{membership_to_remove: %Membership{} = membership, current_user: %User{} = user} =
      socket.assigns

    Clubs.remove_from_club!(membership, actor: user)

    {:noreply,
     socket
     |> assign(:membership_to_remove, nil)
     |> put_flash(:success, dgettext("clubs", "Member removed"))}
  end

  def handle_event("confirm_destroy_invitation", _params, socket) do
    %{invitation_to_destroy: %Invitation{} = invitation, current_user: %User{} = user} =
      socket.assigns

    Clubs.destroy_invitation!(invitation, actor: user)

    {:noreply,
     socket
     |> assign(:invitation_to_destroy, nil)
     |> put_flash(:success, dgettext("clubs", "Invitation deleted"))}
  end

  def handle_event("open_view_invitation_modal", %{"invitation_id" => invitation_id}, socket) do
    %Invitation{} =
      invitation = Enum.find(socket.assigns.club.invitations, fn i -> i.id == invitation_id end)

    {:noreply, socket |> assign(:invitation_to_view, invitation)}
  end

  def handle_event("invitation_link_copied", _params, socket) do
    {:noreply,
     socket |> put_flash(:info, dgettext("clubs", "Invitation link copied to clipboard"))}
  end

  defp not_found(socket) do
    {:noreply,
     socket
     |> put_flash(:error, dgettext("clubs", "The club you were looking for does not exist"))
     |> push_navigate(to: ~p"/")}
  end
end
