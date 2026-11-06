defmodule WatchClubWeb.Components.Conversations.RecommendationText do
  @moduledoc """
  The text sent with a recommendation, between the quote marks of the page's language.
  """
  use WatchClubWeb, :component

  attr :body, :string, required: true
  attr :class, :any, default: nil

  def recommendation_text(assigns) do
    ~H"""
    <q class={[
      "block before:text-accent before:content-[open-quote] after:text-accent after:content-[close-quote]",
      @class
    ]}>{@body}</q>
    """
  end
end
