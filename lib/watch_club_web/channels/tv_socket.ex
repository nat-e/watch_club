defmodule WatchClubWeb.TvSocket do
  @moduledoc """
  The connection of a TV that plays a Playback Session. A TV has no login: the Player that casts
  gives it a signed token, which names the Playback Session, the TV and that Player. The TV acts
  for the User who started the Playback Session, while it's active.
  """
  use Phoenix.Socket

  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.Session
  alias WatchClub.SystemActor
  alias WatchClubWeb.Endpoint

  @salt "tv"

  channel "tv", WatchClubWeb.TvChannel

  @doc "The token that lets the TV take the Playback Session from the Player that casts it."
  def token(%Session{id: session_id}, tv_name, from_screen_id) do
    Phoenix.Token.sign(Endpoint, @salt, %{
      session_id: session_id,
      screen_id: "tv-#{Ash.UUID.generate()}",
      tv_name: tv_name,
      from_screen_id: from_screen_id
    })
  end

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, cast} <- Phoenix.Token.verify(Endpoint, @salt, token, max_age: :infinity),
         {:ok, %Session{ended_at: nil} = session} <-
           Playbacks.get_session_by_id(cast.session_id,
             load: :started_by,
             actor: SystemActor.actor()
           ) do
      {:ok, assign(socket, cast: cast, user: session.started_by)}
    else
      _invalid_token_or_ended_session -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
