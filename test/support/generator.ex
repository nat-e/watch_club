defmodule WatchClub.Generator do
  use Ash.Generator
  alias WatchClub.Accounts.{InvitationCode, User, UserSettings}
  alias WatchClub.Clubs.{Club, Library, Membership}
  alias WatchClub.Contents.{Book, Content, ContentIdentity, Movie, TvShow}
  alias WatchClub.Conversations.{Conversation, Message}
  alias WatchClub.MediaCatalog.Media
  alias WatchClub.MediaSources.{Import, Source}
  alias WatchClub.MediaSources.Servarr.Wizard
  alias WatchClub.Playbacks.{Playback, Session}
  alias WatchClub.Requests.{ContentRequest, MediaSourceRequest, RequestSubscriber}

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

  def user(opts \\ []) do
    {locale, opts} = Keyword.pop(opts, :locale, :en_US)

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
          Ash.Seed.seed!(UserSettings, %{
            user_id: user.id,
            locale: locale
          })

        %{user | settings: settings}
      end
    )
  end

  def club(opts \\ []) do
    changeset_generator(
      Club,
      :create,
      defaults: [
        name: sequence(:name, fn i -> "Club #{i}" end)
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def invitation_code(opts \\ []) do
    changeset_generator(
      InvitationCode,
      :create,
      defaults: [
        code: sequence(:invitation_code, fn i -> "CODE_#{i}" end),
        club_ids: [],
        max_uses: nil
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: Keyword.drop(opts, [:actor])
    )
  end

  def membership(%Club{} = club, %User{} = user, opts \\ []) do
    changeset_generator(
      Membership,
      :create,
      defaults: [
        user_id: user.id,
        club_id: club.id,
        role: :member
      ],
      authorize?: false,
      actor: opts[:actor],
      overrides: opts
    )
  end

  def library(%Club{} = club, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, :movie)

    seed_generator(
      %Library{
        name: sequence(:library_name, fn i -> "Library #{i}" end),
        club_id: club.id,
        content_type: content_type,
        icon: Keyword.get(opts, :icon, "film"),
        index: sequence(:library_index, fn i -> i end)
      },
      overrides: opts
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

  def movie(opts \\ []) do
    seed_generator(
      %Content{
        type: :movie,
        external_id_source: :tmdb,
        external_id: sequence(:tmdb_id, &to_string/1),
        original_title: sequence(:movie_title, &"Movie #{&1}"),
        original_language: "en",
        origin_country: "US",
        release_date: opts[:release_date] || ~D[2025-01-01]
      },
      overrides: opts,
      after_action: fn content ->
        movie =
          Ash.Seed.seed!(Movie, %{
            id: content.id,
            backdrop_path: content.original_title,
            localizations:
              for {iso_639_1, iso_3166_1} <- [{"fr", "FR"}, {"en", "US"}] do
                %{iso_639_1: iso_639_1, iso_3166_1: iso_3166_1, title: content.original_title}
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
        release_date: start_date
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
    seed_generator(
      %Playback{
        session_id: Ash.Seed.seed!(Session, %{started_by_id: generate(user()).id}).id,
        media_id: media.id
      },
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

  def media_source_request(%Content{} = content, %Source{} = media_source, opts \\ []) do
    seed_generator(
      %MediaSourceRequest{
        content_id: content.id,
        media_source_id: media_source.id,
        external_resource_id: sequence(:external_resource_id, & &1)
      },
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

  def media_movie_input(movie_id) do
    %{
      path: "/movies/#{movie_id}/video.mkv",
      type: :movie,
      video: video_input(:movie, movie_id)
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
