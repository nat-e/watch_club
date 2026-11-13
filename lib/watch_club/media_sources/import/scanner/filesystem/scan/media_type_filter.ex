defmodule WatchClub.MediaSources.Import.Scanner.Filesystem.Scan.MediaTypeFilter do
  @moduledoc false

  alias WatchClub.MediaSources.Source

  @video_extensions MapSet.new([
                      ".001",
                      ".3g2",
                      ".3gp",
                      ".amv",
                      ".asf",
                      ".asx",
                      ".avi",
                      ".bin",
                      ".bivx",
                      ".divx",
                      ".dv",
                      ".dvr-ms",
                      ".f4v",
                      ".fli",
                      ".flv",
                      ".ifo",
                      ".img",
                      ".iso",
                      ".m2t",
                      ".m2ts",
                      ".m2v",
                      ".m4v",
                      ".mkv",
                      ".mk3d",
                      ".mov",
                      ".mp4",
                      ".mpe",
                      ".mpeg",
                      ".mpg",
                      ".mts",
                      ".mxf",
                      ".nrg",
                      ".nsv",
                      ".nuv",
                      ".ogg",
                      ".ogm",
                      ".ogv",
                      ".pva",
                      ".qt",
                      ".rec",
                      ".rm",
                      ".rmvb",
                      ".strm",
                      ".svq3",
                      ".tp",
                      ".ts",
                      ".ty",
                      ".viv",
                      ".vob",
                      ".vp3",
                      ".webm",
                      ".wmv",
                      ".wtv",
                      ".xvid"
                    ])

  @ebook_extensions MapSet.new([
                      ".azw",
                      ".azw3",
                      ".cb7",
                      ".cbr",
                      ".cbz",
                      ".djvu",
                      ".epub",
                      ".fb2",
                      ".mobi",
                      ".pdf"
                    ])

  @audiobook_extensions MapSet.new([
                          ".aac",
                          ".aiff",
                          ".alac",
                          ".flac",
                          ".m4a",
                          ".m4b",
                          ".mp3",
                          ".ogg",
                          ".opus",
                          ".wav",
                          ".wma"
                        ])

  def accepted?(path, %Source{} = media_source) do
    extension = path |> Path.extname() |> String.downcase()

    MapSet.member?(extensions_for(media_source.media_type), extension)
  end

  defp extensions_for(media_type) when media_type in [:movie, :tv_show_episode, :sports_event],
    do: @video_extensions

  defp extensions_for(:ebook), do: @ebook_extensions
  defp extensions_for(:audiobook), do: @audiobook_extensions
end
