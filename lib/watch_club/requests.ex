defmodule WatchClub.Requests do
  @moduledoc """
  The request subsystem: a user's `ContentRequest`s and the
  `MediaSourceRequest`s they fan out to. Status is derived, not stored —
  see the resources for details.
  """
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Requests.ContentRequest do
      define :request_content, action: :request, args: [:content_identity]
      define :list_current_user_content_requests, action: :for_current_user

      define :get_current_user_request_for_content,
        action: :for_current_user,
        get_by: [:content_id]

      define :cancel_content_request, action: :cancel
    end

    resource WatchClub.Requests.MediaSourceRequest do
      define :create_media_source_request, action: :create
      define :refresh_media_source_request, action: :refresh_status
      define :destroy_media_source_request, action: :destroy
      define :list_media_source_requests, action: :read
      define :get_media_source_request_by_id, action: :read, get_by: [:id]
    end
  end
end
