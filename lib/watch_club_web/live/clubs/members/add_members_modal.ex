defmodule WatchClubWeb.Live.Clubs.Members.AddMembersModal do
  use WatchClubWeb, :component

  attr :existing_memberships, :list, required: true
  attr :users, :list, required: true

  def add_members_modal(assigns) do
    already_in_club = assigns.existing_memberships |> Enum.map(& &1.user_id)

    assigns =
      assigns
      |> assign(
        already_in_club: already_in_club,
        form: to_form(%{"user_ids" => already_in_club})
      )

    ~H"""
    <.modal id="add_members-modal" size="md" on_close={JS.push("close_modals")}>
      <:title>{dgettext("clubs", "Add club members")}</:title>
      <:description>
        {dgettext(
          "clubs",
          "Add existing users to this club. To invite new users to the instance, go to the Admin > Users page"
        )}
      </:description>
      <.form
        for={@form}
        id="add_members-form"
        phx-submit="submit_add_members"
      >
        <.field field={@form[:user_ids]} label={dgettext("clubs", "Users")}>
          <:control>
            <.checkbox_group
              field={@form[:user_ids]}
              options={@users}
              to_value={& &1.id}
              disabled?={&(&1.id in @already_in_club)}
            >
              <:label :let={user}>
                <.inline space="related"><.avatar id={user.id} name={user.username} />
                  <span>{user.username}</span></.inline>
              </:label>
            </.checkbox_group>
          </:control>
        </.field>

        <:action>
          <.button id="add-members-submit" type="submit" class="w-full">
            {dgettext("clubs", "Add member")}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
