defmodule WatchClubWeb.Components.Clubs.ClubDialogsLive do
  @moduledoc """
  The dialogs that create, delete or leave a club. `WatchClubWeb.Layouts.app/1` renders it once,
  and the sidebar and pages open its dialogs with the functions below.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Clubs.ClubDialogs.CreateClubModal
  import WatchClubWeb.Components.Clubs.ClubDialogs.DeleteClubModal
  import WatchClubWeb.Components.Clubs.ClubDialogs.LeaveClubModal

  alias WatchClubWeb.Hooks.Flash

  @dom_id "club-dialogs"

  def dom_id, do: @dom_id

  def open_create_club_modal(js \\ %JS{}),
    do: JS.push(js, "open_create_club_modal", target: "##{@dom_id}")

  def open_delete_club_modal(js \\ %JS{}, %Club{} = club),
    do: JS.push(js, "open_delete_club_modal", target: "##{@dom_id}", value: %{club_id: club.id})

  def open_leave_club_modal(js \\ %JS{}, %Membership{} = membership) do
    JS.push(js, "open_leave_club_modal",
      target: "##{@dom_id}",
      value: %{membership_id: membership.id}
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <.create_club_modal :if={@create_club_form} form={@create_club_form} myself={@myself} />
      <.delete_club_modal :if={@club_to_delete} club={@club_to_delete} myself={@myself} />
      <.leave_club_modal
        :if={@membership_to_leave}
        membership={@membership_to_leave}
        myself={@myself}
      />
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, reset_modals(socket)}
  end

  @impl true
  def handle_event("open_create_club_modal", _params, socket) do
    form = Clubs.form_to_create_club(actor: socket.assigns.current_user)

    {:noreply, socket |> assign(:create_club_form, to_form(form))}
  end

  def handle_event("validate_create_club", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       :create_club_form,
       AshPhoenix.Form.validate(socket.assigns.create_club_form, params)
     )}
  end

  def handle_event("create_club", %{"form" => params}, socket) do
    %{create_club_form: form} = socket.assigns

    case AshPhoenix.Form.submit(form, params: params, read_one?: true) do
      {:ok, club} ->
        Flash.send_flash(
          :success,
          dgettext("clubs", "Club %{club_name} created", club_name: club.name)
        )

        {:noreply, socket |> assign(:create_club_form, nil)}

      {:error, form} ->
        {:noreply, socket |> assign(:create_club_form, form)}
    end
  end

  def handle_event("open_delete_club_modal", %{"club_id" => club_id}, socket) do
    memberships = socket.assigns.current_user.memberships
    %Membership{club: club} = Enum.find(memberships, fn m -> m.club.id == club_id end)

    {:noreply, socket |> assign(:club_to_delete, club)}
  end

  def handle_event("delete_club", %{"club_id" => club_id}, socket) do
    %{current_user: user} = socket.assigns
    %Membership{club: club} = Enum.find(user.memberships, fn m -> m.club.id == club_id end)

    Clubs.destroy_club!(club, actor: user)

    Flash.send_flash(
      :success,
      dgettext("clubs", "Club %{club_name} deleted", club_name: club.name)
    )

    {:noreply, socket |> assign(:club_to_delete, nil)}
  end

  def handle_event("open_leave_club_modal", %{"membership_id" => membership_id}, socket) do
    memberships = socket.assigns.current_user.memberships
    membership = Enum.find(memberships, fn m -> m.id == membership_id end)

    {:noreply, socket |> assign(:membership_to_leave, membership)}
  end

  def handle_event("leave_club", %{"membership_id" => membership_id}, socket) do
    %{current_user: user} = socket.assigns
    membership = Enum.find(user.memberships, fn m -> m.id == membership_id end)

    Clubs.leave_club!(membership, actor: user)

    Flash.send_flash(
      :success,
      dgettext("clubs", "You left %{club_name}", club_name: membership.club.name)
    )

    {:noreply, socket |> assign(:membership_to_leave, nil)}
  end

  def handle_event("close_modals", _params, socket) do
    {:noreply, reset_modals(socket)}
  end

  defp reset_modals(socket) do
    assign(socket, create_club_form: nil, club_to_delete: nil, membership_to_leave: nil)
  end
end
