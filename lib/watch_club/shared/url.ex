defmodule WatchClub.Shared.Url do
  @moduledoc """
  URL helpers shared across the domain. Lives below the web layer so
  Ash changes and integration clients can depend on it without pulling
  in `WatchClubWeb`.
  """

  @doc """
  Trims surrounding whitespace and strips trailing slashes from a base
  URL. Returns `nil` for `nil`, leaves non-binary values untouched.

  Idempotent — safe to call on already-normalized URLs.
  """
  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

  alias WatchClub.Clubs.Library
  alias WatchClub.Contents.{Content, ContentIdentity, Movie, TvShowEpisode}
  alias WatchClub.MediaCatalog.Video

  @spec normalize_base(nil) :: nil
  @spec normalize_base(String.t()) :: String.t()
  def normalize_base(nil), do: nil

  def normalize_base(url) when is_binary(url) do
    url
    |> String.trim()
    |> String.replace_trailing("/", "")
  end

  @doc """
  Builds the callback URL Watch Club asks a request-capable Media
  Source to POST events to. Format is shared between wizard
  verification and webhook registration, so they must agree.
  """
  @spec webhook_callback_url(String.t(), atom() | String.t(), String.t()) :: String.t()
  def webhook_callback_url(base, source_type, media_source_id)
      when is_binary(base) and is_binary(media_source_id) do
    "#{normalize_base(base)}/webhooks/#{source_type}/#{media_source_id}"
  end

  def content_details_link(%Content{type: type, external_id: id}),
    do: content_details_link(type, id)

  def content_details_link(%ContentIdentity{type: type, external_id: id}),
    do: content_details_link(type, id)

  def content_details_link(:movie, external_id),
    do: ~p"/movies/#{external_id}"

  def content_details_link(:tv_show, external_id),
    do: ~p"/shows/#{external_id}"

  def content_details_link(:book, external_id),
    do: ~p"/books/#{external_id}"

  def player_link(%Movie{} = movie), do: ~p"/play/#{List.first(movie.videos).id}"
  def player_link(%TvShowEpisode{} = episode), do: ~p"/play/#{List.first(episode.videos).id}"
  def player_link([%Video{} = video | _]), do: ~p"/play/#{video.id}"

  def club_library_link(%Library{id: library_id, club_id: club_id}),
    do: ~p"/clubs/#{club_id}/libraries/#{library_id}"
end
