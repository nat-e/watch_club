defmodule WatchClub.Generator do
  use Ash.Generator
  alias WatchClub.Accounts.{InvitationCode, User, UserSettings}

  alias WatchClub.Contents.{
    Book,
    Content,
    ContentIdentity,
    Movie,
    SportsEvent,
    TvShow,
    TvShowEpisode
  }

  alias WatchClub.Conversations.{Conversation, Message}
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources.{Import, Source}
  alias WatchClub.MediaSources.Servarr.Wizard
  alias WatchClub.Playbacks.{Playback, ProblemReport, Session}
  alias WatchClub.Playlists.{Playlist, PlaylistAccess, PlaylistItem}
  alias WatchClub.Requests.{ContentRequest, RequestSubscriber}

  @default_password "passw0rd"
  @default_hashed_password (
                             {:ok, hash} =
                               AshAuthentication.BcryptProvider.hash(@default_password)

                             hash
                           )

  def email, do: sequence(:email, fn i -> "user#{i}@test.com" end)
  def username, do: sequence(:username, fn i -> "user_#{i}" end)

  def administrator(opts \\ []) do
    changeset_generator(
      User,
      :create_administrator,
      defaults: [
        username: username(),
        email: email(),
        password: "passw0rd",
        password_confirmation: "passw0rd",
        locale: :en_US
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  # Takes overrides for the User and their User Preferences
  def user(opts \\ []) do
    {settings, opts} =
      Keyword.split(opts, [
        :locale,
        :audio_language,
        :subtitle_language,
        :languages_without_subtitles
      ])

    # Use seed generator to skip invitation
    seed_generator(
      %User{
        username: username(),
        hashed_password: @default_hashed_password,
        administrator?: false
      },
      overrides: opts,
      after_action: fn user ->
        settings =
          Ash.Seed.seed!(
            UserSettings,
            Enum.into(settings, %{user_id: user.id, locale: :en_US})
          )

        %{user | settings: settings}
      end
    )
  end

  def invitation_code(opts \\ []) do
    changeset_generator(
      InvitationCode,
      :create,
      defaults: [
        code: sequence(:invitation_code, fn i -> "CODE_#{i}" end),
        max_uses: nil
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: Keyword.drop(opts, [:actor])
    )
  end

  def book(opts \\ []) do
    changeset_generator(
      Book,
      :create,
      defaults: [
        original_title: sequence(:book_title, fn i -> "Book #{i}" end),
        hardcover_id: sequence(:hardcover_id, fn i -> i end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  # Takes the `titles` of its Content Localizations by language, such as `%{"fr" => "Titre"}`,
  # which default to its original title
  def movie(opts \\ []) do
    {titles, opts} = Keyword.pop(opts, :titles, %{})

    seed_generator(
      %Content{
        type: :movie,
        external_id_source: :tmdb,
        external_id: sequence(:tmdb_id, &to_string/1),
        original_title: sequence(:movie_title, &"Movie #{&1}"),
        original_language: "en",
        origin_country: "US",
        release_date: opts[:release_date] || ~D[2025-01-01],
        metadata_refreshed_at: DateTime.utc_now()
      },
      overrides: opts,
      after_action: fn content ->
        movie =
          Ash.Seed.seed!(Movie, %{
            id: content.id,
            backdrop_path: content.original_title,
            localizations:
              for {iso_639_1, iso_3166_1} <- [{"fr", "FR"}, {"en", "US"}] do
                %{
                  iso_639_1: iso_639_1,
                  iso_3166_1: iso_3166_1,
                  title: titles[iso_639_1] || content.original_title
                }
              end
          })

        %{content | movie: movie}
      end
    )
  end

  def tv_show(opts \\ []) do
    {num_seasons, opts} = Keyword.pop(opts, :num_seasons, 3)
    {episodes_per_season, opts} = Keyword.pop(opts, :episodes_per_season, 24)
    # Season N airs N years after start_date, one episode a week, so every season has aired by
    # default
    {start_date, opts} = Keyword.pop(opts, :start_date, ~D[2015-01-01])

    episodes =
      for season_number <- 1..num_seasons, episode_number <- 1..episodes_per_season do
        %{
          season_number: season_number,
          episode_number: episode_number,
          air_date: Date.shift(start_date, year: season_number, week: episode_number)
        }
      end

    seed_generator(
      %Content{
        type: :tv_show,
        external_id_source: :tmdb,
        external_id: sequence(:tmdb_id, &to_string/1),
        original_title: sequence(:tv_show_name, &"Show #{&1}"),
        original_language: "en",
        origin_country: "US",
        release_date: start_date,
        metadata_refreshed_at: DateTime.utc_now()
      },
      overrides: opts,
      after_action: fn content ->
        tmdb_id = String.to_integer(content.external_id)

        tv_show =
          Ash.Seed.seed!(TvShow, %{
            id: content.id,
            original_name: content.original_title,
            tmdb_id: tmdb_id,
            tvdb_id: tmdb_id,
            localizations:
              for {iso_639_1, iso_3166_1} <- [{"fr", "FR"}, {"en", "US"}] do
                %{iso_639_1: iso_639_1, iso_3166_1: iso_3166_1, title: content.original_title}
              end,
            episodes: episodes
          })

        %{content | tv_show: tv_show}
      end
    )
  end

  def sports_event(opts \\ []) do
    seed_generator(
      %Content{
        type: :sports_event,
        external_id_source: :sportarr,
        external_id: sequence(:sportarr_event_id, &"ev-#{&1}"),
        original_title: sequence(:sports_event_title, &"UFC #{&1}"),
        original_language: nil,
        origin_country: "US",
        release_date: opts[:release_date] || ~D[2025-01-18],
        metadata_refreshed_at: DateTime.utc_now()
      },
      overrides: opts,
      after_action: fn content ->
        sports_event =
          Ash.Seed.seed!(SportsEvent, %{
            id: content.id,
            title: content.original_title,
            league_id: "lg-000079",
            league_name: "UFC",
            season: "2025"
          })

        %{content | sports_event: sports_event}
      end
    )
  end

  def filesystem_media_source(opts \\ []) do
    changeset_generator(
      Source,
      :create_filesystem,
      defaults: [
        media_type: :movie,
        filesystem_path:
          sequence(:media_source_filesystem_path, fn i -> "tmp/media-imports/#{i}" end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def radarr_media_source(opts \\ []) do
    changeset_generator(
      Source,
      :create_servarr,
      defaults: [
        flavor: :radarr,
        base_url: "http://radarr:7878",
        api_key: "securekey",
        quality_profile_id: 1,
        quality_profile_name: "Movies",
        root_folder_path: "/path/to/radarr",
        webhook_callback_base_url: "http://watch_club:4000"
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def servarr_wizard(opts \\ []) do
    seed_generator(
      %Wizard{
        flavor: :radarr,
        step: :connection,
        base_url: "http://radarr:7878",
        api_key: "securekey"
      },
      overrides: opts
    )
  end

  def media_import(%Source{} = media_source, opts \\ []) do
    {status, opts} = Keyword.pop(opts, :status, :processing)

    seed_generator(
      %Import{
        media_source_id: media_source.id,
        status: status,
        refresh_metadata?: false,
        triggered_manually?: true
      },
      overrides: opts
    )
  end

  def playback(%Media{} = media, opts \\ []) do
    {started_by, opts} = Keyword.pop_lazy(opts, :started_by, fn -> generate(user()) end)

    seed_generator(
      %Playback{
        session_id: Ash.Seed.seed!(Session, %{started_by_id: started_by.id}).id,
        media_id: media.id
      },
      overrides: opts
    )
  end

  # A Playback Session playing the Media in a Player. Takes overrides for the Playback Session,
  # such as `screen_id` and `tv_name` to play on a TV, and `playback:` overrides for its current
  # Playback.
  def playback_session(%Media{} = media, opts \\ []) do
    {started_by, opts} = Keyword.pop_lazy(opts, :started_by, fn -> generate(user()) end)
    {playback, opts} = Keyword.pop(opts, :playback, [])

    seed_generator(
      %Session{started_by_id: started_by.id, screen_id: "player"},
      overrides: opts,
      after_action: fn session ->
        current =
          Ash.Seed.seed!(
            Playback,
            Enum.into(playback, %{session_id: session.id, media_id: media.id})
          )

        %{session | current_playback: current}
      end
    )
  end

  def problem_report(%Playback{} = playback, opts \\ []) do
    seed_generator(
      %ProblemReport{playback_id: playback.id, category: :subtitles, position_seconds: 42.0},
      overrides: opts
    )
  end

  # Without Request Subscribers, unlike Request Content: see `request_subscriber/2`
  def content_request(%User{} = requested_by, %Content{} = content, opts \\ []) do
    seed_generator(
      %ContentRequest{requested_by_id: requested_by.id, content_id: content.id},
      overrides: opts
    )
  end

  def request_subscriber(%User{} = user, %ContentRequest{} = content_request, opts \\ []) do
    seed_generator(
      %RequestSubscriber{user_id: user.id, content_request_id: content_request.id},
      overrides: opts
    )
  end

  def conversation(%User{} = recommended_by, %Content{} = content, recipients, opts \\ []) do
    changeset_generator(
      Conversation,
      :recommend,
      defaults: [
        content_identity: ContentIdentity.from_content(content),
        recipient_ids: Enum.map(recipients, & &1.id)
      ],
      actor: recommended_by,
      overrides: opts
    )
  end

  def message(%Conversation{} = conversation, %User{} = author, opts \\ []) do
    changeset_generator(
      Message,
      :post,
      defaults: [
        conversation_id: conversation.id,
        body: sequence(:message_body, &"Message #{&1}")
      ],
      actor: author,
      overrides: opts
    )
  end

  def playlist(%User{} = owner, opts \\ []) do
    changeset_generator(
      Playlist,
      :create,
      defaults: [
        name: sequence(:playlist_name, &"Playlist #{&1}"),
        icon: "list"
      ],
      authorize?: false,
      actor: owner,
      overrides: opts
    )
  end

  def playlist_access(%Playlist{} = playlist, %User{} = user, level, opts \\ []) do
    seed_generator(%PlaylistAccess{playlist_id: playlist.id, user_id: user.id, level: level},
      overrides: opts
    )
  end

  # Added by the Playlist's owner unless `added_by_id` says otherwise
  def playlist_item(%Playlist{} = playlist, %Content{} = content, opts \\ []) do
    seed_generator(
      %PlaylistItem{
        playlist_id: playlist.id,
        content_id: content.id,
        added_by_id: playlist.owner_id
      },
      overrides: opts
    )
  end

  # Media playing the Movie or the TV Show Episode, or Unmatched Media without either, with the
  # tracks of `video_input/2` unless `video` overrides them
  def video_media(movie_or_episode, opts \\ []) do
    {video, opts} = Keyword.pop(opts, :video, %{})

    {type, folder, id} =
      case movie_or_episode do
        %Content{type: :movie, id: id} -> {:movie, "movies", id}
        %TvShowEpisode{id: id} -> {:tv_show_episode, "episodes", id}
        nil -> {:movie, "unmatched", nil}
      end

    changeset_generator(
      Media,
      :create_video,
      defaults: [
        path: sequence(:video_media_path, &"/#{folder}/#{&1}/video.mkv"),
        type: type,
        video: Map.merge(video_input(type, id), video)
      ],
      authorize?: false,
      overrides: opts
    )
  end

  def media_movie_input(movie_id) do
    %{
      path: "/movies/#{movie_id}/video.mkv",
      type: :movie,
      video: video_input(:movie, movie_id)
    }
  end

  def media_sports_event_input(sports_event_id) do
    %{
      path: "/sports/#{sports_event_id}/video.mkv",
      type: :sports_event,
      video: video_input(:sports_event, sports_event_id)
    }
  end

  def media_episode_input(episode_id) do
    %{
      path: "/episodes/#{episode_id}/video.mkv",
      type: :movie,
      video: video_input(:tv_show_episode, episode_id)
    }
  end

  def video_input(media_type, id) do
    id_field =
      case media_type do
        :movie -> :movie_id
        :tv_show_episode -> :tv_show_episode_id
        :sports_event -> :sports_event_id
      end

    %{
      video_tracks: [%{stream_index: 0, codec: "h264", width: 1920, height: 1080}],
      audio_tracks: [
        %{stream_index: 1, codec: "aac", language: "eng", channels: 2, default?: true}
      ],
      text_tracks: [%{stream_index: 2, codec: "subrip", language: "eng"}]
    }
    |> Map.put(id_field, id)
  end
end
