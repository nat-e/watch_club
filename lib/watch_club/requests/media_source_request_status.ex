defmodule WatchClub.Requests.MediaSourceRequestStatus do
  @moduledoc """
  The status of a Media Source Request
  """

  use Ash.Type.Enum,
    values: [
      # The request has been submitted to Servarr, but nothing has been downloaded
      # This can mean that the search has not finished, or that it has not been found
      :searching,
      # Some media are being downloaded in Servarr
      :downloading,
      # The movie (or all aired episodes for a show) have been downloaded and imported
      # in Servarr, but it has not been imported in Watch Club yet
      :downloaded,
      # There was some issue in Servarr that requires manual action of the admin
      # Most likely the content cannot be matched or extracted, or there was some conflict.
      :needs_attention
    ]
end
