defmodule WatchClubWeb.Modals.CreateInvitation do
  use WatchClubWeb, :live_component

  alias Ash.Error.Changes.Required
  alias WatchClubWeb.Modals.ViewInvitationLink

  @modal_name "create_invitation"
  def modal_name, do: @modal_name

  @impl true
  def render(%{current_user: %User{}, club: %Club{}} = assigns) do
    ~H"""
    <div>
      <.dialog>
        <:title>Invite to club</:title>
        <:description>
          Create a shareable invitation link to join the club
        </:description>
        <.form
          :if={@form}
          for={@form}
          id="invite-club-members-form"
          phx-change="validate"
          phx-submit="submit"
          phx-target={@myself}
          class="flex flex-col gap-6"
        >
          <div class="flex flex-col gap-2">
            <.label field={@form[:name]}>Name</.label>
            <.input
              field={@form[:name]}
              type="name"
              autocomplete="name"
              phx-debounce="blur"
            />
            <.field_errors field={@form[:name]} />
          </div>
          <div class="flex flex-col gap-2">
            <.label field={@form[:role]}>Role</.label>
            <.radio_group field={@form[:role]}>
              <:item value="member">Member</:item>
              <:item value="admin">Admin</:item>
            </.radio_group>
            <.field_errors field={@form[:role]} />
          </div>
          <.button type="submit" class="w-full" phx-submit="submit">
            Create invitation
          </.button>
        </.form>
      </.dialog>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    form = Clubs.form_to_create_invitation(form_opts(assigns))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    %{form: form, current_user: user} = socket.assigns

    case AshPhoenix.Form.submit(form, params: params, read_one?: true, actor: user) do
      {:ok, invitation} ->
        send(
          self(),
          {:close_modal, @modal_name,
           [replace_with: {ViewInvitationLink.modal_name(), invitation.id}]}
        )

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  defp form_opts(assigns) do
    [
      actor: assigns.current_user,
      # Default role for the member
      params: %{role: :member},
      # Append club_id before validate/submit without requiring a hidden field
      prepare_params: fn params, _ -> Map.put(params, :club_id, assigns.club.id) end,
      transform_errors: fn
        _, %Required{field: :role} ->
          {:role, "You must select a role", []}

        _, err ->
          Logger.warning("Unexpected form error: #{inspect(err)}")
          err
      end
    ]
  end
end
