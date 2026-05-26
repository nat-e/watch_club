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
          release_year: integer() | nil,
          original_language: String.t() | nil,
          origin_country: String.t() | nil,
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
      release_year: release_year(media),
      original_language: original_language(media),
      origin_country: origin_country(media),
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
         video: %Video{tv_show_episode: %{formatted_episode_number: formatted}}
       }),
       do: formatted

  defp content_sub(_), do: nil

  # --------------------------------------------------------------------------
  # Content metadata (year / language / country / poster)
  # --------------------------------------------------------------------------

  defp release_year(%Media{} = media) do
    case content(media) do
      %{release_date: %Date{year: year}} -> year
      _ -> nil
    end
  end

  defp original_language(%Media{} = media) do
    case content(media) do
      %{original_language: lang} when is_binary(lang) and lang != "" -> lang
      _ -> nil
    end
  end

  defp origin_country(%Media{} = media) do
    case content(media) do
      %{origin_country: country} when is_binary(country) and country != "" -> country
      _ -> nil
    end
  end

  defp content(%Media{type: :movie, video: %Video{movie: %{content: c}}}), do: c

  defp content(%Media{type: :tv_show_episode, video: %Video{tv_show_episode: %{tv_show: %{content: c}}}}),
    do: c

  defp content(%Media{type: :ebook, ebook: %Ebook{book: %{content: c}}}), do: c
  defp content(%Media{type: :audiobook, audiobook: %Audiobook{book: %{content: c}}}), do: c
  defp content(_), do: nil

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

end
