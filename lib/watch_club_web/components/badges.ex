defmodule WatchClubWeb.Components.Badges do
  use Phoenix.Component

  import Shadcn.Components.Badge

  alias WatchClub.Clubs.Invitation

  attr :role, :atom, required: true

  def role_badge(%{role: :admin} = assigns),
    do: ~H"""
    <.badge variant="secondary">Admin</.badge>
    """

  def role_badge(%{role: :member} = assigns),
    do: ~H"""
    <.badge>Member</.badge>
    """

  def invitation_status_badge(%{invitation: %Invitation{accepted?: true}} = assigns),
    do: ~H"""
    <.badge variant="outline" class="text-emerald-400">Accepted</.badge>
    """

  def invitation_status_badge(%{invitation: %Invitation{expired?: false}} = assigns),
    do: ~H"""
    <.badge variant="outline" class="text-emerald-400">Invited</.badge>
    """

  def invitation_status_badge(%{invitation: %Invitation{}} = assigns),
    do: ~H"""
    <.badge variant="outline" class="text-muted-foreground">Expired</.badge>
    """
end
