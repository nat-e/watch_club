defmodule WatchClubWeb.Helpers.PlaybackPaths do
  @moduledoc """
  The paths of a Playback's files, with a signed token in their `token` query parameter, because a
  TV has no login cookie: a token opens the files of its Playback while it's current. A query
  parameter, which telemetry redacts, keeps it out of logs and traces (see `docs/web-layer.md`).

  A Playback's token never changes, so the Player's source stays the same across renders.
  """
  use Phoenix.VerifiedRoutes,
    endpoint: WatchClubWeb.Endpoint,
    router: WatchClubWeb.Router,
    statics: WatchClubWeb.static_paths()

  alias WatchClub.MediaCatalog.TextTrack
  alias WatchClub.Playbacks.Playback

  @salt "playback"

  def master_playlist(%Playback{id: id} = playback),
    do: ~p"/player/hls/#{id}/master.m3u8?#{[token: token(playback)]}"

  def subtitles(%Playback{id: id} = playback, %TextTrack{id: track_id}),
    do:
      ~p"/player/hls/#{id}/subtitles/#{track_id}/#{"#{track_id}.vtt"}?#{[token: token(playback)]}"

  def thumbnails(%Playback{id: id} = playback),
    do: ~p"/player/thumbnails/#{id}/thumbnails.vtt?#{[token: token(playback)]}"

  @doc "The query that follows the URIs of the files the token opens."
  def query(token), do: "?" <> URI.encode_query(token: token)

  @doc "Whether the token opens the files of the Playback."
  def opens?(token, playback_id),
    do:
      Phoenix.Token.verify(WatchClubWeb.Endpoint, @salt, token, max_age: :infinity) ==
        {:ok, playback_id}

  defp token(%Playback{id: id, inserted_at: inserted_at}),
    do:
      Phoenix.Token.sign(WatchClubWeb.Endpoint, @salt, id,
        signed_at: DateTime.to_unix(inserted_at)
      )
end
