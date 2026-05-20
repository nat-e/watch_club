defmodule WatchClub.Media.MediaType do
  use Ash.Type.Enum,
    values: [
      video: [description: "A video file", label: "Video"],
      ebook: [description: "An ebook file", label: "Ebook"],
      audiobook: [description: "An audiobook file", label: "Audiobook"]
    ]
end
