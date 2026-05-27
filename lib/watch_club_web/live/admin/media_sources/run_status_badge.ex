defmodule WatchClubWeb.Admin.MediaSources.RunStatusBadge do
  @moduledoc """
  Status badge for a `Media Import` (or for a `Media Source` that has never imported).

  The status determines the icon + variant. The label defaults to the
  status's canonical name (e.g. "Completed") but can be overridden via
  the `label` attr when callers want to surface a status-aware message
  ("Last ran 12 minutes ago", "Running for 2 minutes", etc.).
  """
  use WatchClubWeb, :component

  attr :status, :atom,
    required: true,
    values: [:completed, :failed, :cancelled, :processing, :pending, :never_run]

  attr :size, :string, values: ~w(sm md), default: "md"
  attr :label, :string, default: nil

  def run_status_badge(%{status: :completed} = assigns) do
    ~H"""
    <.badge variant="success" size={@size}>
      <:icon><Lucideicons.circle_check /></:icon>
      {@label || dgettext("admin_media_imports", "Completed")}
    </.badge>
    """
  end

  def run_status_badge(%{status: :failed} = assigns) do
    ~H"""
    <.badge variant="danger" size={@size}>
      <:icon><Lucideicons.circle_alert /></:icon>
      {@label || dgettext("admin_media_imports", "Failed")}
    </.badge>
    """
  end

  def run_status_badge(%{status: :cancelled} = assigns) do
    ~H"""
    <.badge variant="muted" size={@size}>
      <:icon><Lucideicons.circle_x /></:icon>
      {@label || dgettext("admin_media_imports", "Cancelled")}
    </.badge>
    """
  end

  def run_status_badge(%{status: :processing} = assigns) do
    ~H"""
    <.badge variant="accent" size={@size}>
      <:icon><Lucideicons.loader_circle class="animate-spin" /></:icon>
      {@label || dgettext("admin_media_imports", "In progress")}
    </.badge>
    """
  end

  def run_status_badge(%{status: :pending} = assigns) do
    ~H"""
    <.badge variant="muted" size={@size}>
      <:icon><Lucideicons.clock /></:icon>
      {@label || dgettext("admin_media_imports", "Pending")}
    </.badge>
    """
  end

  def run_status_badge(%{status: :never_run} = assigns) do
    ~H"""
    <.badge variant="muted" size={@size}>
      <:icon><Lucideicons.circle_dashed /></:icon>
      {@label || dgettext("admin_media_imports", "Never imported")}
    </.badge>
    """
  end
end
