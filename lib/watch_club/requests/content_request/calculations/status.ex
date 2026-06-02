defmodule WatchClub.Requests.ContentRequest.Calculations.Status do
  @moduledoc """
  The displayed `ContentRequestStatus`, derived from the Content's Media (the
  fulfillment authority) and its Media Source Requests (best-wins), plus a
  grace window for freshly-created requests.

  An **expression** calculation (`expression/2`), not in-memory `calculate/3`,
  so it stays pushable to SQL — the My Requests `status_group` filter sorts
  and filters on it.

  Precedence: completed > downloading > importing > not_released > requested >
  failed > not_found. (`not_released` outranks `requested` — a known "no
  release yet" is more informative than the generic queued/searching grace.)

  `downloaded` maps to `:importing`, never `:completed` — only Media presence
  completes a request. So the file finishing in *arr shows "importing" until
  WatchClub ingests it, and never a false "completed" (if ingest stalls, it
  honestly sits at importing). The MSR only reaches `downloaded` once nothing
  is downloading (a movie's one file, or a show's drained queue), so a show
  stays in `downloading` for its whole fetch rather than flickering.

  "Complete" is tested inline (movie- vs show-complete) rather than via the
  integer `progress` calc, because inlining an integer CASE here trips
  Postgres CASE-type unification.
  """
  use Ash.Resource.Calculation

  import Ash.Expr

  @impl true
  def expression(_opts, _context) do
    expr(
      cond do
        content.type == :movie and movie_video_count > 0 ->
          :completed

        content.type == :tv_show and aired_episode_count > 0 and
            aired_available_episode_count >= aired_episode_count ->
          :completed

        downloading_request_count > 0 ->
          :downloading

        downloaded_request_count > 0 ->
          :importing

        # A series with some (but not all aired) episodes and nothing actively
        # downloading still reads as in-progress to the user.
        partially_downloaded_request_count > 0 ->
          :downloading

        not_released_request_count > 0 ->
          :not_released

        fresh_submitted_request_count > 0 ->
          :requested

        request_count == 0 and inserted_at > ago(5, :minute) ->
          :requested

        needs_attention_request_count > 0 ->
          :failed

        true ->
          :not_found
      end
    )
  end
end
