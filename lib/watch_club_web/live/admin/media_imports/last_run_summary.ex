defmodule WatchClubWeb.Admin.MediaImports.LastRunSummary do
  @moduledoc """
  Inline summary of a configuration's most recent `Media Import`.

  Renders the status badge plus the run's relative start time. When the
  configuration has never run, only the "Never imported" badge is shown.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaImports.RunStatusBadge

  alias WatchClub.Media.ImportRun
  alias WatchClubWeb.Helpers.Time

  attr :latest_run, :any, required: true
  attr :locale, :atom, required: true

  def last_run_summary(%{latest_run: nil} = assigns) do
    ~H"""
    <.run_status_badge status={:never_run} />
    """
  end

  def last_run_summary(%{latest_run: %ImportRun{status: :processing}} = assigns) do
    ~H"""
    <.run_status_badge
      status={@latest_run.status}
      label={dgettext("admin_media_imports", "In progress")}
    />
    """
  end

  def last_run_summary(%{latest_run: %ImportRun{}} = assigns) do
    ~H"""
    <.run_status_badge
      status={@latest_run.status}
      label={
        dgettext("admin_media_imports", "Last ran %{relative_time}",
          relative_time: Time.relative_from_now(@latest_run.inserted_at, @locale)
        )
      }
    />
    """
  end
end
