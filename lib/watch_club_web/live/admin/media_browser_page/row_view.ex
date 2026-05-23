defmodule WatchClubWeb.Admin.MediaBrowserPage.RowView do
  @moduledoc """
  Presenter helpers that turn a fully-preloaded `Media` row into the values
  the table / drawer components render. Keeps presentational logic out of
  HEEX templates.
  """

  alias WatchClub.Media.{Audiobook, Ebook, Media, Video}

  @type t :: %{
          id: binary(),
          path: String.t(),
          file_name: String.t(),
          media_type: :movie | :tv_show_episode | :ebook | :audiobook,
          content_title: String.t() | nil,
          content_sub: String.t() | nil,
          clubs: [%{id: binary(), name: String.t()}],
          resolution: :uhd_4k | :hd_1080p | :hd_720p | :sd | nil,
          audio_languages: [String.t()],
          subtitle_languages: [String.t()],
          imported_at: DateTime.t() | nil
        }

  @spec from_media(Media.t()) :: t()
  def from_media(%Media{} = media) do
    %{
      id: media.id,
      path: media.path,
      file_name: Path.basename(media.path || ""),
      media_type: media.type,
      content_title: content_title(media),
      content_sub: content_sub(media),
      clubs: clubs(media),
      resolution: resolution(media),
      audio_languages: audio_languages(media),
      subtitle_languages: subtitle_languages(media),
      imported_at: media.inserted_at
    }
  end

  # --------------------------------------------------------------------------
  # Content title + sub
  # --------------------------------------------------------------------------

  defp content_title(%Media{type: :movie, video: %Video{movie: %{content: %{original_title: t}}}}), do: t

  defp content_title(%Media{
         type: :tv_show_episode,
         video: %Video{tv_show_episode: %{tv_show: %{content: %{original_title: t}}}}
       }),
       do: t

  defp content_title(%Media{type: :ebook, ebook: %Ebook{book: %{title: t}}}), do: t
  defp content_title(%Media{type: :audiobook, audiobook: %Audiobook{book: %{title: t}}}), do: t
  defp content_title(_), do: nil

  defp content_sub(%Media{
         type: :tv_show_episode,
         video: %Video{tv_show_episode: %{season_number: s, episode_number: e}}
       }) do
     "S#{pad(s)}E#{pad(e)}"
  end

  defp content_sub(_), do: nil

  defp pad(n) when is_integer(n) and n < 10, do: "0#{n}"
  defp pad(n) when is_integer(n), do: Integer.to_string(n)

  # --------------------------------------------------------------------------
  # Clubs (union across attachment paths)
  # --------------------------------------------------------------------------

  defp clubs(%Media{} = media) do
    media
    |> library_items()
    |> Enum.map(fn item -> item.library.club end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.name)
  end

  defp library_items(%Media{type: :movie, video: %Video{movie: %{content: %{library_items: items}}}})
       when is_list(items),
       do: items

  defp library_items(%Media{
         type: :tv_show_episode,
         video: %Video{tv_show_episode: %{tv_show: %{content: %{library_items: items}}}}
       })
       when is_list(items),
       do: items

  defp library_items(%Media{type: :ebook, ebook: %Ebook{book: %{content: %{library_items: items}}}})
       when is_list(items),
       do: items

  defp library_items(%Media{type: :audiobook, audiobook: %Audiobook{book: %{content: %{library_items: items}}}})
       when is_list(items),
       do: items

  defp library_items(_), do: []

  # --------------------------------------------------------------------------
  # Resolution (video only; bucket from height)
  # --------------------------------------------------------------------------

  defp resolution(%Media{video: %Video{video_tracks: tracks}}) when is_list(tracks) do
    tracks
    |> Enum.map(& &1.height)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
    |> bucket()
  end

  defp resolution(_), do: nil

  defp bucket(nil), do: nil
  defp bucket(h) when h >= 1900, do: :uhd_4k
  defp bucket(h) when h >= 1000, do: :hd_1080p
  defp bucket(h) when h >= 700, do: :hd_720p
  defp bucket(_), do: :sd

  # --------------------------------------------------------------------------
  # Audio / subtitle languages
  # --------------------------------------------------------------------------

  defp audio_languages(%Media{video: %Video{audio_tracks: tracks}}) when is_list(tracks) do
    tracks
    |> Enum.map(& &1.language)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp audio_languages(_), do: []

  defp subtitle_languages(%Media{video: %Video{text_tracks: tracks}}) when is_list(tracks) do
    tracks
    |> Enum.map(& &1.language)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp subtitle_languages(_), do: []

  # --------------------------------------------------------------------------
  # Localized labels
  # --------------------------------------------------------------------------

  @spec resolution_label(:uhd_4k | :hd_1080p | :hd_720p | :sd | nil) :: String.t() | nil
  def resolution_label(:uhd_4k), do: "4K"
  def resolution_label(:hd_1080p), do: "1080p"
  def resolution_label(:hd_720p), do: "720p"
  def resolution_label(:sd), do: "SD"
  def resolution_label(_), do: nil

  @doc """
  Splits a filename into `{head, tail}` so the head can truncate with an
  ellipsis while the tail (extension + a few preceding characters) stays
  visible — a middle-ellipsis effect achieved purely with flex layout.
  """
  @spec split_file_name(String.t()) :: {String.t(), String.t()}
  def split_file_name(name) when is_binary(name) do
    len = String.length(name)
    tail_len = 12

    if len <= tail_len + 4 do
      {name, ""}
    else
      {String.slice(name, 0, len - tail_len), String.slice(name, len - tail_len, tail_len)}
    end
  end

  @spec language_flag(String.t()) :: String.t()
  def language_flag(lang) when is_binary(lang) do
    code =
      case String.downcase(lang) do
        "en" -> "GB"
        "eng" -> "GB"
        "fr" -> "FR"
        "fra" -> "FR"
        "ja" -> "JP"
        "jpn" -> "JP"
        "es" -> "ES"
        "spa" -> "ES"
        "de" -> "DE"
        "deu" -> "DE"
        "it" -> "IT"
        "ita" -> "IT"
        "pt" -> "PT"
        "por" -> "PT"
        "zh" -> "CN"
        "chi" -> "CN"
        "ko" -> "KR"
        "kor" -> "KR"
        _ -> "UN"
      end

    code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end
end
