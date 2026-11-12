defmodule WatchClub.History do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  alias WatchClub.History.{HiddenFromHome, WatchProgress}

  resources do
    resource WatchProgress do
      define :record_watch_progress, action: :record_progress

      define :mark_content_watched, args: [:content_identity]
      define :mark_content_not_watched, args: [:content_identity]
      define :list_watchers, action: :watchers, args: [:content_identity]
    end

    resource HiddenFromHome do
      define :hide_from_home, action: :hide, args: [:content_id]

      define :show_on_home,
        action: :show,
        args: [:content_id],
        require_reference?: false,
        default_options: [bulk_options: [notify?: true]]
    end
  end
end
