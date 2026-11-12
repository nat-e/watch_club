defmodule WatchClub.History do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.History.{HiddenFromContinueWatching, WatchProgress}

  resources do
    resource WatchProgress do
      define :record_watch_progress, action: :record_progress

      define :mark_content_watched, args: [:content_identity]
      define :mark_content_not_watched, args: [:content_identity]
      define :list_watchers, action: :watchers, args: [:content_identity]
    end

    resource HiddenFromContinueWatching do
      define :hide_from_continue_watching, action: :hide, args: [:content_id]

      define :unhide_from_continue_watching,
        action: :unhide,
        args: [:content_id],
        require_reference?: false,
        default_options: [bulk_options: [notify?: true]]
    end
  end
end
