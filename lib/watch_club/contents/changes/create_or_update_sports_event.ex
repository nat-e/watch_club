defmodule WatchClub.Contents.Changes.CreateOrUpdateSportsEvent do
  @moduledoc """
  Fetches a Sports Event from sportarr.net and writes its Content and SportsEvent.
  sportarr.net doesn't say in which language an event is, so it has no original language.
  """
  use Ash.Resource.Change

  alias WatchClub.Contents.{MetadataUnavailable, SportsEvent}
  alias WatchClub.Integrations.SportarrHub

  require Logger

  @impl true
  def change(changeset, _opts, context) do
    sportarr_id =
      Ash.Changeset.get_attribute(changeset, :external_id) ||
        Ash.Changeset.get_argument(changeset, :content_identity).external_id

    Ash.Changeset.before_transaction(changeset, fn changeset ->
      Logger.info("Refreshing Sports Event metadata for Sportarr ID: #{sportarr_id}",
        event: :refreshing_sports_event_metadata,
        sportarr_id: sportarr_id
      )

      case SportarrHub.get_event(sportarr_id, cache: false) do
        {:ok, event} ->
          changeset
          |> Ash.Changeset.force_change_attributes(%{
            type: :sports_event,
            external_id_source: :sportarr,
            external_id: event.id,
            original_title: event.title,
            original_language: nil,
            origin_country: event.country,
            release_date: event.date,
            genres: [],
            rating: nil,
            metadata_refreshed_at: DateTime.utc_now()
          })
          |> Ash.Changeset.after_action(fn _changeset, content ->
            Ash.bulk_create!(
              [
                %{
                  id: content.id,
                  title: event.title,
                  overview: event.overview,
                  league_id: event.league_id,
                  league_name: event.league_name,
                  season: event.season,
                  venue: event.venue,
                  starts_at: event.starts_at,
                  poster_url: event.poster_url,
                  backdrop_url: event.backdrop_url
                }
              ],
              SportsEvent,
              :create,
              scope: context
            )

            {:ok, content}
          end)

        {:error, reason} ->
          Ash.Changeset.add_error(changeset, MetadataUnavailable.exception(reason: reason))
      end
    end)
  end
end
