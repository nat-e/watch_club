defmodule WatchClubWeb.UI.Badges do
  @moduledoc """
  Token-driven Watch Club badges.
  """

  use Phoenix.Component

  alias WatchClub.Clubs.Invitation

  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(default secondary success muted danger),
    default: "default"

  attr :size, :string, values: ~w(sm md), default: "md"

  attr :rest, :global

  slot :icon do
    attr :class, :any
  end

  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-full border border-transparent font-medium whitespace-nowrap",
        @size == "sm" && "h-5 px-2 py-0.5 text-xs",
        @size == "md" && "h-6 px-2.5 py-1 text-sm",
        @variant == "default" && "bg-primary text-on-primary",
        @variant == "secondary" && "border-border bg-surface-raised text-text",
        @variant == "success" && "border-success-border bg-success-bg text-success",
        @variant == "muted" && "border-border-subtle bg-surface-inset text-text-muted",
        @variant == "danger" && "border-danger-border bg-danger-bg text-danger",
        @class
      ]}
      {@rest}
    >
      <span
        :for={icon <- @icon}
        class={[
          "inline-flex shrink-0 items-center justify-center [&_svg]:pointer-events-none",
          @size == "sm" && "[&_svg]:size-3",
          @size == "md" && "[&_svg]:size-3.5",
          icon[:class]
        ]}
      >
        {render_slot(icon)}
      </span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :role, :atom, required: true

  def role_badge(%{role: :admin} = assigns) do
    ~H"""
    <.badge>Admin</.badge>
    """
  end

  def role_badge(%{role: :member} = assigns) do
    ~H"""
    <.badge variant="secondary">Member</.badge>
    """
  end

  attr :invitation, Invitation, required: true

  def invitation_status_badge(%{invitation: %Invitation{accepted?: true}} = assigns) do
    ~H"""
    <.badge variant="success">Accepted</.badge>
    """
  end

  def invitation_status_badge(%{invitation: %Invitation{expired?: false}} = assigns) do
    ~H"""
    <.badge variant="success">Invited</.badge>
    """
  end

  def invitation_status_badge(%{invitation: %Invitation{}} = assigns) do
    ~H"""
    <.badge variant="muted">Expired</.badge>
    """
  end
end
