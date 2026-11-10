defmodule WatchClub.MediaSources do
  use Ash.Domain,
    otp_app: :watch_club,
    extensions: [AshPhoenix]

  resources do
    resource WatchClub.MediaSources.Source do
      define :list_media_sources, action: :read
      define :get_media_source_by_id, action: :read, get_by: [:id]
      define :create_filesystem_media_source, action: :create_filesystem
      define :create_servarr_media_source, action: :create_servarr
      define :destroy_media_source, action: :destroy
      define :list_request_capable_sources, action: :request_capable, args: [:media_types]
    end

    resource WatchClub.MediaSources.Filesystem do
      define :update_filesystem_media_source, action: :update
    end

    resource WatchClub.MediaSources.Servarr do
      define :update_servarr_media_source, action: :update
      define :handle_servarr_webhook, action: :handle_webhook, args: [:servarr, :payload]
    end

    resource WatchClub.MediaSources.Import do
      define :list_media_imports, action: :read
      define :get_media_import_by_id, action: :read, get_by: [:id]
      define :start_media_import, action: :start, args: [:media_source_id]
      define :cancel_media_import, action: :cancel
    end

    resource WatchClub.MediaSources.Servarr.Wizard do
      define :create_servarr_wizard_for_create, action: :for_create, args: [:flavor]
      define :create_servarr_wizard_for_edit, action: :for_edit, args: [:media_source]
      define :configure_servarr_connection, action: :configure_connection
      define :configure_servarr_request_profile, action: :configure_request_profile
      define :configure_servarr_webhook, action: :configure_webhook
      define :servarr_wizard_back_to_previous_step, action: :back_to_previous_step
    end
  end
end
