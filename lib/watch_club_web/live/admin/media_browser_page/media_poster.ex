defmodule WatchClubWeb.Admin.MediaBrowserPage.MediaPoster do
  @moduledoc """
  A Media's poster, and its Content's title, both from the Content's Preferred Content
  Localization. Books have no Content Localization: they show their own title, and an icon for
  their Media Type instead of a poster, as Unmatched Media show a question mark.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Media.MediaTypeBadge

  attr :media, Media, required: true, doc: "with its `content`'s `implementation` loaded"
  attr :size, :string, values: ~w(sm lg), required: true

  def media_poster(assigns) do
    assigns = assign(assigns, :path, poster_path(assigns.media.content))

    ~H"""
    <.tmdb_poster
      :if={@path}
      path={@path}
      size={if @size == "sm", do: "w92", else: "w185"}
      class={["shrink-0 rounded-md!", @size == "sm" && "w-8", @size == "lg" && "w-20"]}
    />
    <div
      :if={!@path}
      class={[
        "grid aspect-2/3 shrink-0 place-items-center rounded-md bg-surface-inset text-text-muted",
        @size == "sm" && "w-8",
        @size == "lg" && "w-20"
      ]}
    >
      <Lucideicons.file_question_mark :if={!@media.content} class="size-icon-sm" />
      <.media_type_icon :if={@media.content} media_type={@media.type} class="size-icon-sm" />
    </div>
    """
  end

  @doc "A Content's title in the User's language, with its `implementation` loaded."
  def content_title(%Content{implementation: %Book{title: title}}), do: title

  def content_title(%Content{implementation: implementation}),
    do: implementation.best_localization.title

  defp poster_path(nil), do: nil
  defp poster_path(%Content{implementation: %Book{}}), do: nil

  defp poster_path(%Content{implementation: implementation}),
    do: implementation.best_localization.poster_path
end
