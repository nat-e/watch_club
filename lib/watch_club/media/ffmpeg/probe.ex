defmodule WatchClub.Media.Ffmpeg.Probe do
  @moduledoc """
  Behaviour for inspecting a media file's container/streams metadata.

  Production implementation is `WatchClub.Media.Ffmpeg.probe/1`. Tests swap
  in a mock via `config :watch_club, :ffprobe, ...`.
  """

  @callback probe(path :: String.t()) :: {:ok, map()} | {:error, term()}
end
