defmodule WatchClubWeb.Admin.MediaSources.LastImportSummary do
  @moduledoc """
  Inline summary of a Media Source's most recent `Media Import`.

  Renders the status badge plus the Media Import's relative start time. When
  the Media Source has never run a Media Import, only the "Never imported"
  badge is shown.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Admin.MediaSources.RunStatusBadge

  alias WatchClub.MediaSources.Import
  alias WatchClubWeb.Helpers.Time

  attr :latest_import, :any, required: true
  attr :locale, :atom, required: true

  def last_import_summary(%{latest_import: nil} = assigns) do
    ~H"""
    <.run_status_badge status={:never_run} />
    """
  end

  def last_import_summary(%{latest_import: %Import{status: :processing}} = assigns) do
    ~H"""
    <.run_status_badge
      status={@latest_import.status}
      label={dgettext("admin_media_imports", "In progress")}
    />
    """
  end

  def last_import_summary(%{latest_import: %Import{}} = assigns) do
    ~H"""
    <.run_status_badge
      status={@latest_import.status}
      label={
        dgettext("admin_media_imports", "Last ran %{relative_time}",
          relative_time: Time.relative_from_now(@latest_import.inserted_at, @locale)
        )
      }
    />
    """
  end
end
