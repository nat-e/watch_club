defmodule WatchClub.Media.ImportPipeline.Scan.IgnoreRules do
  @moduledoc false

  @ignored_directory_names MapSet.new([
                             "metadata",
                             "ps3_update",
                             "ps3_vprm",
                             "extrafanart",
                             "extrathumbs",
                             ".actors",
                             ".wd_tv",
                             "lost+found",
                             "subs",
                             ".snapshots",
                             ".snapshot",
                             ".zfs",
                             "sample",
                             "samples",
                             "minta",
                             "trailers",
                             "backdrops",
                             "theme-music",
                             "behind the scenes",
                             "deleted scenes",
                             "interviews",
                             "scenes",
                             "shorts",
                             "featurettes",
                             "extras",
                             "extra",
                             "other",
                             "clips",
                             "ps3_update",
                             "temprec",
                             "tempsbe",
                             "eadir",
                             "@eadir",
                             "#recycle",
                             "@recycle",
                             ".@__thumb",
                             "$recycle.bin",
                             "system volume information",
                             ".grab"
                           ])

  @ignored_file_names MapSet.new([
                        "small.jpg",
                        "albumart.jpg",
                        "thumbs.db"
                      ])

  @ignored_file_extensions MapSet.new([".bts", ".sync"])

  @extra_suffixes [
    "trailer",
    "sample",
    "theme",
    "scene",
    "clip",
    "interview",
    "behindthescenes",
    "deleted",
    "deletedscene",
    "featurette",
    "short",
    "extra",
    "other"
  ]

  def directory_ignored?(path, root_path) do
    path_ignored?(path, root_path) or
      MapSet.member?(@ignored_directory_names, basename_downcased(path))
  end

  def file_ignored?(path, root_path) do
    path_ignored?(path, root_path) or file_basename_ignored?(path)
  end

  defp path_ignored?(path, root_path) do
    if path == root_path do
      false
    else
      segments = path_segments_under_root(path, root_path)
      hidden_path?(segments) or trickplay_path?(segments)
    end
  end

  defp file_basename_ignored?(path) do
    basename = basename_downcased(path)
    stem = path |> Path.basename(Path.extname(path)) |> String.downcase()
    extension = path |> Path.extname() |> String.downcase()

    MapSet.member?(@ignored_file_names, basename) or
      MapSet.member?(@ignored_file_extensions, extension) or
      sample_file?(stem) or
      extra_file?(stem)
  end

  defp basename_downcased(path), do: path |> Path.basename() |> String.downcase()

  defp path_segments_under_root(path, root_path) do
    path
    |> Path.relative_to(root_path)
    |> Path.split()
  end

  defp hidden_path?(segments) do
    Enum.any?(segments, fn segment -> String.starts_with?(segment, ".") end)
  end

  defp sample_file?(stem) do
    stem == "sample" or
      stem == "minta" or
      String.ends_with?(stem, ".sample") or
      String.ends_with?(stem, "-sample") or
      String.ends_with?(stem, "_sample") or
      String.ends_with?(stem, ".minta") or
      String.ends_with?(stem, "-minta") or
      String.ends_with?(stem, "_minta")
  end

  defp extra_file?(stem) do
    Enum.any?(@extra_suffixes, fn suffix ->
      stem == suffix or
        String.ends_with?(stem, ".#{suffix}") or
        String.ends_with?(stem, "-#{suffix}") or
        String.ends_with?(stem, "_#{suffix}") or
        String.ends_with?(stem, " #{suffix}")
    end)
  end

  defp trickplay_path?(segments) do
    Enum.any?(segments, fn segment ->
      segment
      |> String.downcase()
      |> String.contains?(".trickplay")
    end)
  end
end
