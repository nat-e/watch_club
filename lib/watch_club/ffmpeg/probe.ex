defmodule WatchClub.Ffmpeg.Probe do
  @moduledoc """
  Behaviour for inspecting a media file: its container, streams and chapters,
  the keyframes of its video with the video's bytes from each to the next, and
  the fingerprint of its audio.

  Production implementation is `WatchClub.Ffmpeg`. Tests swap in a mock via
  `config :watch_club, :ffprobe, ...`.
  """

  @callback probe(path :: String.t()) :: {:ok, map()} | {:error, term()}

  @callback keyframes(path :: String.t(), stream_index :: non_neg_integer()) ::
              {:ok, [{seconds :: float(), bytes :: non_neg_integer()}]} | {:error, term()}

  @callback audio_fingerprint(path :: String.t(), from_seconds :: number(), seconds :: number()) ::
              {:ok, [non_neg_integer()]} | {:error, term()}
end
