defmodule WatchClub.Playbacks.ProblemReport.Category do
  @moduledoc "What's wrong, as the User picks it when they Report a Problem."
  use Ash.Type.Enum,
    values: [
      audio: [description: "Wrong language, out of sync, missing or bad sound"],
      subtitles: [description: "Wrong language, out of sync, missing or wrong text"],
      picture_quality: [description: "Blurry, blocky or glitchy picture"],
      slow: [description: "Slow to start, or keeps stopping to load"],
      wrong_video: [description: "Not the Movie or Episode the User picked"],
      player: [description: "The Player shows an error, or a button does nothing"],
      other: [description: "Something else"]
    ]
end
