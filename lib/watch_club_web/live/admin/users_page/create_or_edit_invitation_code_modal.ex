defmodule WatchClubWeb.Live.Admin.UsersPage.CreateOrEditInvitationCodeModal do
  use WatchClubWeb, :component

  attr :form, Phoenix.HTML.Form, required: true
  attr :current_user, User, required: true

  def create_invitation_code_modal(assigns) do
    edit? = assigns.form.source.type == :update

    assigns =
      assigns
      |> assign(
        edit?: edit?,
        title:
          (edit? && dgettext("admin_invitations", "Edit invitation code")) ||
            dgettext("clubs", "Create invitation code"),
        submit_label:
          (edit? && dgettext("admin_invitations", "Save")) ||
            dgettext("admin_invitations", "Create"),
        clubs: Enum.map(assigns.current_user.memberships, & &1.club)
      )

    ~H"""
    <.modal id="create-invitation-code-modal" on_close={JS.push("close_modals")}>
      <:title>{@title}</:title>
      <:description>
        {dgettext(
          "admin_invitations",
          "Create an invitation link and share it with your friends. The link will expire after 7 days"
        )}
      </:description>
      <.form
        for={@form}
        id="create-invitation-form"
        phx-change="validate_invitation_form"
        phx-submit="submit_invitation_form"
      >
        <.field
          field={@form[:code]}
          label={dgettext("admin_invitations", "Code")}
          type="text"
          disabled={@edit?}
        >
          <:hint :if={@edit?}>
            {dgettext("admin_invitations", "The code cannot be changed once created.")}
          </:hint>
        </.field>
        <.field field={@form[:club_ids]} label={dgettext("admin_invitations", "Clubs access")}>
          <:hint>
            {dgettext(
              "admin_invitations",
              "Users joining through this invitation will automatically be added to the Clubs you select below"
            )}
          </:hint>
          <:control>
            <.checkbox_group
              field={@form[:club_ids]}
              options={@clubs}
              to_value={& &1.id}
            >
              <:label :let={club}>
                <.inline space="related"><.avatar id={club.id} name={club.name} />
                  <span>{club.name}</span></.inline>
              </:label>
            </.checkbox_group>
          </:control>
        </.field>

        <.field
          field={@form[:max_uses]}
          label={dgettext("admin_invitations", "Usage limit")}
          type="number"
          min="1"
          placeholder={dgettext("admin_invitations", "Unlimited")}
        >
          <:hint>
            {dgettext(
              "admin_invitations",
              "Maximum number of accounts this invitation can create. Leave empty for unlimited."
            )}
          </:hint>
        </.field>

        <:action>
          <.button id="submit-invitation-submit-button" type="submit" class="w-full">
            {@submit_label}
          </.button>
        </:action>
      </.form>
    </.modal>
    """
  end
end
