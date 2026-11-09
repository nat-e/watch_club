defmodule WatchClub.Requests do
  @moduledoc """
  The request subsystem: each Content's `ContentRequest`, its `RequestSubscriber`s, and the
  `MediaSourceRequest`s it fans out to. Status is derived, not stored — see the resources for
  details.
  """
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.Requests.ContentRequest do
      define :request_content, action: :request, args: [:content_identity]
      define :list_current_user_ready_requests, action: :ready_for_current_user

      define :list_current_user_ready_unseen_requests,
        action: :ready_unseen_for_current_user

      define :list_current_user_requests_on_the_way, action: :on_the_way_for_current_user

      define :get_current_user_request_for_content,
        action: :for_current_user,
        get_by: [:content_id]

      define :delete_content_request, action: :destroy
    end

    resource WatchClub.Requests.RequestSubscriber do
      define :get_notified, action: :create, args: [:content_request_id]
      define :stop_getting_notified, action: :destroy, get_by: [:content_request_id]
      define :mark_current_user_requests_seen, action: :mark_all_ready_seen
    end

    resource WatchClub.Requests.MediaSourceRequest do
      define :create_media_source_request, action: :create
      define :destroy_media_source_request, action: :destroy
    end
  end
end
