defmodule WatchClubWeb.Live.Admin.UsersPage.InvitationCodesSection do
  use WatchClubWeb, :component

  alias WatchClub.Accounts.InvitationCode
  alias WatchClubWeb.Helpers.{Time, Url}

  attr :invitations, :list, required: true
  attr :current_user, User, required: true
  attr :current_url, Url, required: true

  def invitation_codes_section(assigns) when assigns.invitations == [] do
    ~H"""
    <.empty size="sm">
      <:icon><Lucideicons.mail /></:icon>
      <:title>{dgettext("admin_invitations", "You don't have any active invite links")}</:title>
    </.empty>
    """
  end

  def invitation_codes_section(assigns) do
    ~H"""
    <.section space="related" padding="group" title="Active Invitations" icon={:mail}>
      <.cluster>
        <.invitation_card
          :for={invitation <- @invitations}
          invitation={invitation}
          locale={@current_user.settings.locale}
          current_url={@current_url}
        />
      </.cluster>
    </.section>
    """
  end

  attr :invitation, InvitationCode, required: true
  attr :locale, :atom, required: true
  attr :current_url, Url, required: true

  defp invitation_card(assigns) do
    max_uses = assigns.invitation.max_uses

    assigns =
      assigns
      |> assign(
        :usage_percent,
        (max_uses && min(100, round(assigns.invitation.uses / max_uses * 100))) || 0
      )
      |> assign(
        :invitation_link,
        Url.invitation_url(assigns.current_url, assigns.invitation) |> Url.to_url(absolute: true)
      )

    ~H"""
    <.card class="flex w-72 flex-col gap-cluster" surface="raised">
      <%!-- The code is the hero: an inset token with an affixed copy button. --%>
      <.inline class="justify-between">
        <.inline
          space="tight"
          class="h-control-md min-w-0 rounded-md border border-border-subtle bg-surface-inset pr-tight pl-related"
        >
          <span class="min-w-0 flex-1 truncate font-mono text-base font-semibold tracking-wide">
            {@invitation.code}
          </span>
          <span
            id={"share-invitation-link-#{@invitation.id}"}
            class="hidden"
            phx-no-format
          >{@invitation_link}</span>
          <.button
            id={"copy-invitation-code-#{@invitation.id}"}
            type="button"
            phx-click={
              JS.dispatch("wc:copy_to_clipboard", to: "#share-invitation-link-#{@invitation.id}")
              |> JS.push("invitation_link_copied")
              |> JS.transition("copied", time: 3000, blocking: false)
            }
            aria-label={dgettext("admin_invitations", "Copy invitation link")}
            size="icon-sm"
            variant="ghost"
            class="group relative inline-flex transition-colors [&.copied]:text-success"
          >
            <Lucideicons.copy class="size-icon-sm group-[.copied]:hidden" />
            <Lucideicons.check class="absolute size-icon-sm hidden group-[.copied]:block" />
          </.button>
        </.inline>
        <.invitation_actions invitation={@invitation} />
      </.inline>

      <.stack space="group">
        <.stack space="related">
          <.text_label text={dgettext("admin_invitations", "Clubs Access")} />
          <.avatar_group avatars={@invitation.clubs} avatar_size="sm" />
        </.stack>

        <.stack space="related">
          <.inline class="justify-between">
            <.text_label text={dgettext("admin_invitations", "Uses")} />
            <span class="font-mono text-sm tabular-nums text-text">
              {@invitation.uses}
              <span :if={@invitation.max_uses}>
                / {@invitation.max_uses}
              </span>
            </span>
          </.inline>
          <div class="h-2 w-full rounded-full bg-surface-inset">
            <div class="h-full rounded-full bg-accent" style={"width: #{@usage_percent}%"}></div>
          </div>
        </.stack>

        <.inline space="related" class="justify-between">
          <.text_label text={dgettext("admin_invitations", "Expires")} />
          <span class="inline-flex items-center gap-tight text-xs text-text-muted">
            <Lucideicons.clock class="size-icon-sm" />
            {Time.relative_from_now(@invitation.expires_at, @locale)}
          </span>
        </.inline>
      </.stack>
    </.card>
    """
  end

  attr :invitation, InvitationCode, required: true

  defp invitation_actions(assigns) do
    ~H"""
    <.dropdown_menu id={"invitation-actions-#{@invitation.id}"}>
      <:trigger>
        <.button
          id={"invitation-actions-trigger-#{@invitation.id}"}
          size="icon"
          variant="secondary"
          aria-label={dgettext("admin_invitations", "Invitation actions")}
        >
          <Lucideicons.ellipsis_vertical />
        </.button>
      </:trigger>
      <.dropdown_menu_item
        id={"edit-invitation-code-#{@invitation.id}"}
        phx-click="open_edit_invitation_code_modal"
        phx-value-id={@invitation.id}
      >
        <Lucideicons.edit /> {dgettext("admin_invitations", "Edit")}
      </.dropdown_menu_item>
      <.dropdown_menu_separator />
      <.dropdown_menu_item
        id={"delete-invitation-code-#{@invitation.id}"}
        variant="destructive"
        phx-click="open_delete_invitation_code_modal"
        phx-value-id={@invitation.id}
      >
        <Lucideicons.trash /> {dgettext("admin_invitations", "Delete")}
      </.dropdown_menu_item>
    </.dropdown_menu>
    """
  end
end
