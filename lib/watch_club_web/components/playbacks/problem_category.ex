defmodule WatchClubWeb.Components.Playbacks.ProblemCategory do
  @moduledoc """
  What's wrong in a Problem Report, as its icon and its name. `name/1` and `icon/1` give them
  apart, for the form that picks one.
  """
  use WatchClubWeb, :component

  alias WatchClub.Playbacks.ProblemReport.Category

  attr :category, :atom, required: true, values: Category.values()
  attr :class, :any, default: nil

  def problem_category(assigns) do
    ~H"""
    <span class={["inline-flex min-w-0 items-center gap-related", @class]}>
      <.lucide_icon name={icon(@category)} class="size-icon-sm shrink-0 text-text-muted" />
      <span class="truncate">{name(@category)}</span>
    </span>
    """
  end

  def name(:audio), do: dgettext("player", "Audio")
  def name(:subtitles), do: dgettext("player", "Subtitles")
  def name(:picture_quality), do: dgettext("player", "Picture quality")
  def name(:slow), do: dgettext("player", "Slow or buffering")
  def name(:wrong_video), do: dgettext("player", "Wrong video")
  def name(:player), do: dgettext("player", "Player not working")
  def name(:other), do: dgettext("player", "Other")

  def icon(:audio), do: "audio-lines"
  def icon(:subtitles), do: "captions"
  def icon(:picture_quality), do: "image"
  def icon(:slow), do: "snail"
  def icon(:wrong_video), do: "file-question-mark"
  def icon(:player), do: "bug"
  def icon(:other), do: "ellipsis"
end
