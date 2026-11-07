defmodule WatchClub.Repo.Migrations.Init do
  @moduledoc """
  Creates the WatchClub schema, extensions, background jobs and instance settings.
  """

  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_or(left BOOLEAN, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE)
    AS $$ SELECT COALESCE(NULLIF($1, FALSE), $2) $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_or(left ANYCOMPATIBLE, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE)
    AS $$ SELECT COALESCE($1, $2) $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_and(left BOOLEAN, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE) AS $$
      SELECT CASE
        WHEN $1 IS TRUE THEN $2
        ELSE $1
      END $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_elixir_and(left ANYCOMPATIBLE, in right ANYCOMPATIBLE, out f1 ANYCOMPATIBLE) AS $$
      SELECT CASE
        WHEN $1 IS NOT NULL THEN $2
        ELSE $1
      END $$
    LANGUAGE SQL
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_trim_whitespace(arr text[])
    RETURNS text[] AS $$
    DECLARE
        start_index INT = 1;
        end_index INT = array_length(arr, 1);
    BEGIN
        WHILE start_index <= end_index AND arr[start_index] = '' LOOP
            start_index := start_index + 1;
        END LOOP;

        WHILE end_index >= start_index AND arr[end_index] = '' LOOP
            end_index := end_index - 1;
        END LOOP;

        IF start_index > end_index THEN
            RETURN ARRAY[]::text[];
        ELSE
            RETURN arr[start_index : end_index];
        END IF;
    END; $$
    LANGUAGE plpgsql
    SET search_path = ''
    IMMUTABLE;
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb)
    RETURNS BOOLEAN AS $$
    BEGIN
        -- Raise an error with the provided JSON data.
        -- The JSON object is converted to text for inclusion in the error message.
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal ANYCOMPATIBLE)
    RETURNS ANYCOMPATIBLE AS $$
    BEGIN
        -- Raise an error with the provided JSON data.
        -- The JSON object is converted to text for inclusion in the error message.
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_required(value ANYCOMPATIBLE, payload jsonb)
    RETURNS ANYCOMPATIBLE AS $$
    BEGIN
      IF value IS NULL THEN
        RAISE EXCEPTION 'ash_error: %', payload::text;
      END IF;

      RETURN value;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    execute("""
    CREATE OR REPLACE FUNCTION uuid_generate_v7()
    RETURNS UUID
    AS $$
    DECLARE
      timestamp    TIMESTAMPTZ;
      microseconds INT;
    BEGIN
      timestamp    = clock_timestamp();
      microseconds = (cast(extract(microseconds FROM timestamp)::INT - (floor(extract(milliseconds FROM timestamp))::INT * 1000) AS DOUBLE PRECISION) * 4.096)::INT;

      RETURN encode(
        set_byte(
          set_byte(
            overlay(uuid_send(gen_random_uuid()) placing substring(int8send(floor(extract(epoch FROM timestamp) * 1000)::BIGINT) FROM 3) FROM 1 FOR 6
          ),
          6, (b'0111' || (microseconds >> 8)::bit(4))::bit(8)::int
        ),
        7, microseconds::bit(8)::int
      ),
      'hex')::UUID;
    END
    $$
    LANGUAGE PLPGSQL
    SET search_path = ''
    VOLATILE;
    """)

    execute("CREATE EXTENSION IF NOT EXISTS \"citext\"")
    execute("CREATE EXTENSION IF NOT EXISTS \"unaccent\"")

    create table(:messages, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :kind, :text, null: false
      add :body, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :conversation_id, :uuid, null: false
      add :author_id, :uuid
    end

    create index(:messages, [:conversation_id, :id])

    create table(:playback_sessions, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :started_by_id, :uuid, null: false
    end

    create table(:playbacks, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :last_active_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :ended_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :session_id,
          references(:playback_sessions,
            column: :id,
            name: "playbacks_session_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false

      add :media_id, :uuid, null: false
    end

    create table(:conversations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:messages) do
      modify :conversation_id,
             references(:conversations,
               column: :id,
               name: "messages_conversation_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:conversations) do
      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :content_id, :uuid, null: false
      add :recommended_by_id, :uuid
    end

    create index(:conversations, [:content_id])

    create table(:servarr_media_sources, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :flavor, :text, null: false
      add :base_url, :text, null: false
      add :api_key, :text, null: false
      add :quality_profile_id, :bigint, null: false
      add :quality_profile_name, :text, null: false
      add :root_folder_path, :text, null: false
      add :local_root_folder_path, :text
      add :webhook_callback_base_url, :text, null: false
      add :webhook_secret, :text, null: false
      add :notification_id, :bigint, null: false
    end

    create table(:movies, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
    end

    create unique_index(:movies, [:id], name: "movies_unique_content_index")

    alter table(:movies) do
      add :backdrop_path, :text
    end

    create table(:media_sources, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:servarr_media_sources) do
      modify :id,
             references(:media_sources,
               column: :id,
               name: "servarr_media_sources_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:media_sources) do
      add :name, :text, null: false
      add :source_type, :text, null: false, default: "filesystem"
      add :media_type, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:tv_show_episodes, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :season_number, :bigint, null: false
      add :episode_number, :bigint, null: false
      add :air_date, :date
      add :still_path, :text
      add :tv_show_id, :uuid, null: false
    end

    create unique_index(:tv_show_episodes, [:tv_show_id, :season_number, :episode_number],
             name: "tv_show_episodes_unique_position_per_tv_show_index"
           )

    create table(:media_source_requests, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :status, :text, null: false, default: "searching"
      add :download_progress, :float, null: false, default: 0.0
      add :external_resource_id, :bigint, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :content_id, :uuid, null: false

      add :media_source_id,
          references(:media_sources,
            column: :id,
            name: "media_source_requests_media_source_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create unique_index(:media_source_requests, [:content_id, :media_source_id],
             name: "media_source_requests_unique_content_source_index"
           )

    create table(:participants, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :conversation_id,
          references(:conversations,
            column: :id,
            name: "participants_conversation_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false

      add :user_id, :uuid
    end

    create unique_index(:participants, [:conversation_id, :user_id],
             name: "participants_user_in_conversation_index"
           )

    alter table(:participants) do
      add :last_read_message_id,
          references(:messages,
            column: :id,
            name: "participants_last_read_message_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )
    end

    create index(:participants, [:user_id])

    create table(:audio_tracks, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :stream_index, :bigint, null: false
      add :codec, :text, null: false
      add :language, :text
      add :title, :text
      add :channels, :bigint
      add :is_default, :boolean, null: false, default: false
      add :video_id, :uuid, null: false
    end

    create table(:video_tracks, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :stream_index, :bigint, null: false
      add :codec, :text, null: false
      add :width, :bigint, null: false
      add :height, :bigint, null: false
      add :frame_rate, :float
      add :bit_rate, :bigint
      add :is_default, :boolean, null: false, default: false
      add :video_id, :uuid, null: false
    end

    create table(:content_requests, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :requested_by_id, :uuid
      add :content_id, :uuid, null: false
    end

    create unique_index(:content_requests, [:content_id],
             name: "content_requests_unique_content_index"
           )

    alter table(:content_requests) do
      add :best_source_request_id,
          references(:media_source_requests,
            column: :id,
            name: "content_requests_best_source_request_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )
    end

    create table(:playlist_accesses, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :level, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :playlist_id, :uuid, null: false
      add :user_id, :uuid, null: false
    end

    create unique_index(:playlist_accesses, [:playlist_id, :user_id],
             name: "playlist_accesses_playlist_and_user_index"
           )

    create table(:users, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:messages) do
      modify :author_id,
             references(:users,
               column: :id,
               name: "messages_author_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :nilify_all
             )
    end

    alter table(:playback_sessions) do
      modify :started_by_id,
             references(:users,
               column: :id,
               name: "playback_sessions_started_by_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:conversations) do
      modify :recommended_by_id,
             references(:users,
               column: :id,
               name: "conversations_recommended_by_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :nilify_all
             )
    end

    alter table(:participants) do
      modify :user_id,
             references(:users,
               column: :id,
               name: "participants_user_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :nilify_all
             )
    end

    alter table(:content_requests) do
      modify :requested_by_id,
             references(:users,
               column: :id,
               name: "content_requests_requested_by_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :nilify_all
             )
    end

    alter table(:playlist_accesses) do
      modify :user_id,
             references(:users,
               column: :id,
               name: "playlist_accesses_user_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:users) do
      add :username, :text, null: false
      add :hashed_password, :text, null: false
      add :confirmed_at, :utc_datetime_usec
      add :is_administrator, :boolean, null: false, default: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:users, [:is_administrator],
             name: "users_only_one_administrator_index",
             where: "(is_administrator = true)"
           )

    create unique_index(:users, [:username], name: "users_unique_username_index")

    create table(:media, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:playbacks) do
      modify :media_id,
             references(:media,
               column: :id,
               name: "playbacks_media_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:media) do
      add :path, :text, null: false
      add :type, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :content_id, :uuid
    end

    create unique_index(:media, [:path], name: "media_unique_path_index")

    create table(:media_imports, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :refresh_metadata, :boolean, null: false, default: false
      add :is_triggered_manually, :boolean, null: false, default: true
      add :finished_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :status, :text, null: false, default: "processing"

      add :media_source_id,
          references(:media_sources,
            column: :id,
            name: "media_imports_media_source_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create index(:media_imports, [:media_source_id],
             name: "media_imports_one_processing_per_media_source_index",
             unique: true,
             where: "status = 'processing'"
           )

    create table(:request_subscribers, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :is_ready_unseen, :boolean, null: false, default: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :content_request_id,
          references(:content_requests,
            column: :id,
            name: "request_subscribers_content_request_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false

      add :user_id,
          references(:users,
            column: :id,
            name: "request_subscribers_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create unique_index(:request_subscribers, [:content_request_id, :user_id],
             name: "request_subscribers_unique_request_and_user_index"
           )

    create table(:activity_feed_content_watched_events, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :group_key, :text, null: false

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :completed, :boolean, null: false, default: false
      add :completed_episodes, {:array, :map}

      add :actor_id,
          references(:users,
            column: :id,
            name: "activity_feed_content_watched_events_actor_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false

      add :content_id, :uuid, null: false
    end

    create unique_index(:activity_feed_content_watched_events, [:actor_id, :content_id],
             name: "acwe_unique_per_actor_content_index"
           )

    create table(:tokens, primary_key: false) do
      add :jti, :text, null: false, primary_key: true
      add :subject, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :purpose, :text, null: false
      add :extra_data, :map

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create table(:tv_show_localizations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :iso_639_1, :text, null: false
      add :iso_3166_1, :text, null: false
      add :title, :text, null: false
      add :overview, :text
      add :poster_path, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tv_show_id, :uuid, null: false
    end

    create unique_index(:tv_show_localizations, [:tv_show_id, :iso_639_1, :iso_3166_1],
             name: "tv_show_localizations_unique_locale_per_tv_show_index"
           )

    create table(:contents, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:conversations) do
      modify :content_id,
             references(:contents,
               column: :id,
               name: "conversations_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:movies) do
      modify :id,
             references(:contents,
               column: :id,
               name: "movies_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:media_source_requests) do
      modify :content_id,
             references(:contents,
               column: :id,
               name: "media_source_requests_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:content_requests) do
      modify :content_id,
             references(:contents,
               column: :id,
               name: "content_requests_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:media) do
      modify :content_id,
             references(:contents,
               column: :id,
               name: "media_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :restrict
             )
    end

    alter table(:activity_feed_content_watched_events) do
      modify :content_id,
             references(:contents,
               column: :id,
               name: "activity_feed_content_watched_events_content_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    create index(:activity_feed_content_watched_events, [:group_key])

    alter table(:contents) do
      add :type, :text, null: false
      add :external_id_source, :text, null: false
      add :external_id, :text, null: false
      add :original_title, :text, null: false
      add :original_language, :text, null: false
      add :origin_country, :text, null: false
      add :release_date, :date
      add :genres, {:array, :text}, null: false, default: []
      add :rating, :float

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:contents, [:external_id_source, :external_id],
             name: "contents_external_id_index"
           )

    create table(:instance_settings, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :name, :text, null: false, default: "Watch Club"
      add :singleton, :boolean, null: false, default: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:instance_settings, [:singleton],
             name: "instance_settings_singleton_index"
           )

    create constraint(:instance_settings, :instance_settings_singleton_check,
             check: """
               singleton = true
             """
           )

    create table(:text_tracks, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :stream_index, :bigint
      add :sidecar_path, :text
      add :codec, :text, null: false
      add :language, :text
      add :title, :text
      add :is_default, :boolean, null: false, default: false
      add :is_forced, :boolean, null: false, default: false
      add :video_id, :uuid, null: false
    end

    create table(:movie_localizations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :iso_639_1, :text, null: false
      add :iso_3166_1, :text, null: false
      add :title, :text, null: false
      add :overview, :text
      add :poster_path, :text
      add :runtime, :bigint

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :movie_id,
          references(:movies,
            column: :id,
            name: "movie_localizations_movie_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create unique_index(:movie_localizations, [:movie_id, :iso_639_1, :iso_3166_1],
             name: "movie_localizations_unique_locale_per_movie_index"
           )

    create table(:watch_progresses, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :position_seconds, :float
      add :duration_seconds, :float

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "watch_progresses_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :movie_id,
          references(:movies,
            column: :id,
            name: "watch_progresses_movie_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )

      add :book_id, :uuid

      add :tv_show_episode_id,
          references(:tv_show_episodes,
            column: :id,
            name: "watch_progresses_tv_show_episode_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )
    end

    create unique_index(:watch_progresses, [:user_id, :book_id, :movie_id, :tv_show_episode_id],
             name: "watch_progresses_unique_content_per_user_index",
             nulls_distinct: false
           )

    alter table(:watch_progresses) do
      add :last_media_id,
          references(:media,
            column: :id,
            name: "watch_progresses_last_media_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )
    end

    create index(:watch_progresses, [:user_id, :movie_id])

    create index(:watch_progresses, [:user_id, :tv_show_episode_id])

    create table(:ebooks, primary_key: false) do
      add :id,
          references(:media,
            column: :id,
            name: "ebooks_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), primary_key: true, null: false

      add :book_id, :uuid, null: false
    end

    create table(:user_settings, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :locale, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "user_settings_user_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create unique_index(:user_settings, [:user_id], name: "user_settings_unique_user_index")

    create table(:playlists, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
    end

    alter table(:playlist_accesses) do
      modify :playlist_id,
             references(:playlists,
               column: :id,
               name: "playlist_accesses_playlist_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:playlists) do
      add :name, :text, null: false
      add :icon, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :owner_id,
          references(:users,
            column: :id,
            name: "playlists_owner_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create table(:videos, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
    end

    alter table(:audio_tracks) do
      modify :video_id,
             references(:videos,
               column: :id,
               name: "audio_tracks_video_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:video_tracks) do
      modify :video_id,
             references(:videos,
               column: :id,
               name: "video_tracks_video_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:text_tracks) do
      modify :video_id,
             references(:videos,
               column: :id,
               name: "text_tracks_video_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    create constraint(:text_tracks, :text_tracks_exactly_one_text_track_source_check,
             check: """
               num_nonnulls(stream_index, sidecar_path) = 1
             """
           )

    alter table(:videos) do
      modify :id,
             references(:media,
               column: :id,
               name: "videos_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )

      add :duration_seconds, :float
      add :container, :text
      add :bit_rate, :bigint

      add :movie_id,
          references(:movies,
            column: :id,
            name: "videos_movie_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :restrict
          )

      add :tv_show_episode_id,
          references(:tv_show_episodes,
            column: :id,
            name: "videos_tv_show_episode_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :restrict
          )
    end

    create constraint(:videos, :videos_at_most_one_content_attachment_check,
             check: """
               num_nonnulls(movie_id, tv_show_episode_id) <= 1
             """
           )

    create table(:tv_shows, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
    end

    create unique_index(:tv_shows, [:id], name: "tv_shows_unique_content_index")

    alter table(:tv_show_episodes) do
      modify :tv_show_id,
             references(:tv_shows,
               column: :id,
               name: "tv_show_episodes_tv_show_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:tv_show_localizations) do
      modify :tv_show_id,
             references(:tv_shows,
               column: :id,
               name: "tv_show_localizations_tv_show_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )
    end

    alter table(:tv_shows) do
      modify :id,
             references(:contents,
               column: :id,
               name: "tv_shows_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )

      add :original_name, :text, null: false
      add :backdrop_path, :text
      add :tmdb_id, :bigint, null: false
    end

    create unique_index(:tv_shows, [:tmdb_id], name: "tv_shows_unique_tmdb_id_index")

    alter table(:tv_shows) do
      add :tvdb_id, :bigint
    end

    create unique_index(:tv_shows, [:tvdb_id], name: "tv_shows_unique_tvdb_id_index")

    create table(:books, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
    end

    create unique_index(:books, [:id], name: "books_unique_content_index")

    alter table(:watch_progresses) do
      modify :book_id,
             references(:books,
               column: :id,
               name: "watch_progresses_book_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    alter table(:ebooks) do
      modify :book_id,
             references(:books,
               column: :id,
               name: "ebooks_book_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :restrict
             )
    end

    alter table(:books) do
      modify :id,
             references(:contents,
               column: :id,
               name: "books_id_fkey",
               type: :uuid,
               prefix: "public",
               on_delete: :delete_all
             )

      add :title, :text, null: false
      add :hardcover_id, :bigint, null: false
    end

    create unique_index(:books, [:hardcover_id], name: "books_unique_hardcover_id_index")

    create table(:invitation_codes, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true
      add :code, :text, null: false
      add :max_uses, :bigint
      add :uses, :bigint, default: 0
      add :expires_at, :utc_datetime_usec, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:invitation_codes, [:code], name: "invitation_codes_unique_code_index")

    create table(:audiobooks, primary_key: false) do
      add :id,
          references(:media,
            column: :id,
            name: "audiobooks_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), primary_key: true, null: false

      add :book_id,
          references(:books,
            column: :id,
            name: "audiobooks_book_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :restrict
          ), null: false
    end

    create table(:filesystem_media_sources, primary_key: false) do
      add :id,
          references(:media_sources,
            column: :id,
            name: "filesystem_media_sources_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), primary_key: true, null: false

      add :filesystem_path, :text, null: false
    end

    create table(:playlist_items, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v7()"), primary_key: true

      add :added_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :playlist_id,
          references(:playlists,
            column: :id,
            name: "playlist_items_playlist_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false

      add :content_id,
          references(:contents,
            column: :id,
            name: "playlist_items_content_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ), null: false
    end

    create unique_index(:playlist_items, [:playlist_id, :content_id],
             name: "playlist_items_playlist_and_content_index"
           )

    alter table(:playlist_items) do
      add :added_by_id,
          references(:users,
            column: :id,
            name: "playlist_items_added_by_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )
    end

    execute """
    CREATE VIEW activity_feed_entries AS
    SELECT group_key, max(created_at) AS latest_at
    FROM activity_feed_content_watched_events
    GROUP BY group_key
    """

    execute """
    INSERT INTO instance_settings (id, name, singleton, inserted_at, updated_at)
    VALUES (uuid_generate_v7(), 'Watch Club', true, now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc')
    """

    Oban.Migration.up(version: 14)

  end

  def down do
    Oban.Migration.down(version: 1)
    execute "DROP VIEW activity_feed_entries"

    drop constraint(:playlist_items, "playlist_items_added_by_id_fkey")

    drop constraint(:playlist_items, "playlist_items_content_id_fkey")

    drop constraint(:playlist_items, "playlist_items_playlist_id_fkey")

    alter table(:playlist_items) do
      remove :added_by_id
    end

    drop_if_exists unique_index(:playlist_items, [:playlist_id, :content_id],
                     name: "playlist_items_playlist_and_content_index"
                   )

    drop table(:playlist_items)

    drop constraint(:filesystem_media_sources, "filesystem_media_sources_id_fkey")

    drop table(:filesystem_media_sources)

    drop constraint(:audiobooks, "audiobooks_book_id_fkey")

    drop constraint(:audiobooks, "audiobooks_id_fkey")

    drop table(:audiobooks)

    drop_if_exists unique_index(:invitation_codes, [:code],
                     name: "invitation_codes_unique_code_index"
                   )

    drop table(:invitation_codes)

    drop constraint(:books, "books_id_fkey")

    drop_if_exists unique_index(:books, [:hardcover_id], name: "books_unique_hardcover_id_index")

    alter table(:books) do
      remove :hardcover_id
      remove :title
      modify :id, :uuid
    end

    drop constraint(:ebooks, "ebooks_book_id_fkey")

    drop constraint(:ebooks, "ebooks_id_fkey")

    alter table(:ebooks) do
      modify :book_id, :uuid
    end

    drop constraint(:watch_progresses, "watch_progresses_last_media_id_fkey")

    drop constraint(:watch_progresses, "watch_progresses_tv_show_episode_id_fkey")

    drop constraint(:watch_progresses, "watch_progresses_book_id_fkey")

    drop constraint(:watch_progresses, "watch_progresses_movie_id_fkey")

    drop constraint(:watch_progresses, "watch_progresses_user_id_fkey")

    alter table(:watch_progresses) do
      modify :book_id, :uuid
    end

    drop_if_exists unique_index(:books, [:id], name: "books_unique_content_index")

    drop table(:books)

    drop constraint(:tv_shows, "tv_shows_id_fkey")

    drop_if_exists unique_index(:tv_shows, [:tvdb_id], name: "tv_shows_unique_tvdb_id_index")

    alter table(:tv_shows) do
      remove :tvdb_id
    end

    drop_if_exists unique_index(:tv_shows, [:tmdb_id], name: "tv_shows_unique_tmdb_id_index")

    alter table(:tv_shows) do
      remove :tmdb_id
      remove :backdrop_path
      remove :original_name
      modify :id, :uuid
    end

    drop constraint(:tv_show_localizations, "tv_show_localizations_tv_show_id_fkey")

    alter table(:tv_show_localizations) do
      modify :tv_show_id, :uuid
    end

    drop constraint(:tv_show_episodes, "tv_show_episodes_tv_show_id_fkey")

    alter table(:tv_show_episodes) do
      modify :tv_show_id, :uuid
    end

    drop_if_exists unique_index(:tv_shows, [:id], name: "tv_shows_unique_content_index")

    drop table(:tv_shows)

    drop_if_exists constraint(:videos, :videos_at_most_one_content_attachment_check)

    drop constraint(:videos, "videos_tv_show_episode_id_fkey")

    drop constraint(:videos, "videos_movie_id_fkey")

    drop constraint(:videos, "videos_id_fkey")

    alter table(:videos) do
      remove :tv_show_episode_id
      remove :movie_id
      remove :bit_rate
      remove :container
      remove :duration_seconds
      modify :id, :uuid
    end

    drop_if_exists constraint(:text_tracks, :text_tracks_exactly_one_text_track_source_check)

    drop constraint(:text_tracks, "text_tracks_video_id_fkey")

    alter table(:text_tracks) do
      modify :video_id, :uuid
    end

    drop constraint(:video_tracks, "video_tracks_video_id_fkey")

    alter table(:video_tracks) do
      modify :video_id, :uuid
    end

    drop constraint(:audio_tracks, "audio_tracks_video_id_fkey")

    alter table(:audio_tracks) do
      modify :video_id, :uuid
    end

    drop table(:videos)

    drop constraint(:playlists, "playlists_owner_id_fkey")

    alter table(:playlists) do
      remove :owner_id
      remove :updated_at
      remove :inserted_at
      remove :icon
      remove :name
    end

    drop constraint(:playlist_accesses, "playlist_accesses_user_id_fkey")

    drop constraint(:playlist_accesses, "playlist_accesses_playlist_id_fkey")

    alter table(:playlist_accesses) do
      modify :playlist_id, :uuid
    end

    drop table(:playlists)

    drop constraint(:user_settings, "user_settings_user_id_fkey")

    drop_if_exists unique_index(:user_settings, [:user_id],
                     name: "user_settings_unique_user_index"
                   )

    drop table(:user_settings)

    drop table(:ebooks)

    drop_if_exists index(:watch_progresses, [:user_id, :tv_show_episode_id])

    drop_if_exists index(:watch_progresses, [:user_id, :movie_id])

    alter table(:watch_progresses) do
      remove :last_media_id
    end

    drop_if_exists unique_index(
                     :watch_progresses,
                     [:user_id, :book_id, :movie_id, :tv_show_episode_id],
                     name: "watch_progresses_unique_content_per_user_index"
                   )

    drop table(:watch_progresses)

    drop constraint(:movie_localizations, "movie_localizations_movie_id_fkey")

    drop_if_exists unique_index(:movie_localizations, [:movie_id, :iso_639_1, :iso_3166_1],
                     name: "movie_localizations_unique_locale_per_movie_index"
                   )

    drop table(:movie_localizations)

    drop table(:text_tracks)

    drop_if_exists constraint(:instance_settings, :instance_settings_singleton_check)

    drop_if_exists unique_index(:instance_settings, [:singleton],
                     name: "instance_settings_singleton_index"
                   )

    drop table(:instance_settings)

    drop_if_exists unique_index(:contents, [:external_id_source, :external_id],
                     name: "contents_external_id_index"
                   )

    alter table(:contents) do
      remove :updated_at
      remove :inserted_at
      remove :rating
      remove :genres
      remove :release_date
      remove :origin_country
      remove :original_language
      remove :original_title
      remove :external_id
      remove :external_id_source
      remove :type
    end

    drop_if_exists index(:activity_feed_content_watched_events, [:group_key])

    drop constraint(
           :activity_feed_content_watched_events,
           "activity_feed_content_watched_events_content_id_fkey"
         )

    drop constraint(
           :activity_feed_content_watched_events,
           "activity_feed_content_watched_events_actor_id_fkey"
         )

    alter table(:activity_feed_content_watched_events) do
      modify :content_id, :uuid
    end

    drop constraint(:media, "media_content_id_fkey")

    alter table(:media) do
      modify :content_id, :uuid
    end

    drop constraint(:content_requests, "content_requests_best_source_request_id_fkey")

    drop constraint(:content_requests, "content_requests_content_id_fkey")

    drop constraint(:content_requests, "content_requests_requested_by_id_fkey")

    alter table(:content_requests) do
      modify :content_id, :uuid
    end

    drop constraint(:media_source_requests, "media_source_requests_media_source_id_fkey")

    drop constraint(:media_source_requests, "media_source_requests_content_id_fkey")

    alter table(:media_source_requests) do
      modify :content_id, :uuid
    end

    drop constraint(:movies, "movies_id_fkey")

    alter table(:movies) do
      modify :id, :uuid
    end

    drop constraint(:conversations, "conversations_recommended_by_id_fkey")

    drop constraint(:conversations, "conversations_content_id_fkey")

    alter table(:conversations) do
      modify :content_id, :uuid
    end

    drop table(:contents)

    drop_if_exists unique_index(:tv_show_localizations, [:tv_show_id, :iso_639_1, :iso_3166_1],
                     name: "tv_show_localizations_unique_locale_per_tv_show_index"
                   )

    drop table(:tv_show_localizations)

    drop table(:tokens)

    drop_if_exists unique_index(:activity_feed_content_watched_events, [:actor_id, :content_id],
                     name: "acwe_unique_per_actor_content_index"
                   )

    drop table(:activity_feed_content_watched_events)

    drop constraint(:request_subscribers, "request_subscribers_user_id_fkey")

    drop constraint(:request_subscribers, "request_subscribers_content_request_id_fkey")

    drop_if_exists unique_index(:request_subscribers, [:content_request_id, :user_id],
                     name: "request_subscribers_unique_request_and_user_index"
                   )

    drop table(:request_subscribers)

    drop_if_exists index(:media_imports, [:media_source_id],
                     name: "media_imports_one_processing_per_media_source_index"
                   )

    drop constraint(:media_imports, "media_imports_media_source_id_fkey")

    drop table(:media_imports)

    drop_if_exists unique_index(:media, [:path], name: "media_unique_path_index")

    alter table(:media) do
      remove :content_id
      remove :updated_at
      remove :inserted_at
      remove :type
      remove :path
    end

    drop constraint(:playbacks, "playbacks_media_id_fkey")

    drop constraint(:playbacks, "playbacks_session_id_fkey")

    alter table(:playbacks) do
      modify :media_id, :uuid
    end

    drop table(:media)

    drop_if_exists unique_index(:users, [:username], name: "users_unique_username_index")

    drop_if_exists unique_index(:users, [:is_administrator],
                     name: "users_only_one_administrator_index"
                   )

    alter table(:users) do
      remove :updated_at
      remove :inserted_at
      remove :is_administrator
      remove :confirmed_at
      remove :hashed_password
      remove :username
    end

    alter table(:playlist_accesses) do
      modify :user_id, :uuid
    end

    alter table(:content_requests) do
      modify :requested_by_id, :uuid
    end

    drop constraint(:participants, "participants_last_read_message_id_fkey")

    drop constraint(:participants, "participants_user_id_fkey")

    drop constraint(:participants, "participants_conversation_id_fkey")

    alter table(:participants) do
      modify :user_id, :uuid
    end

    alter table(:conversations) do
      modify :recommended_by_id, :uuid
    end

    drop constraint(:playback_sessions, "playback_sessions_started_by_id_fkey")

    alter table(:playback_sessions) do
      modify :started_by_id, :uuid
    end

    drop constraint(:messages, "messages_author_id_fkey")

    drop constraint(:messages, "messages_conversation_id_fkey")

    alter table(:messages) do
      modify :author_id, :uuid
    end

    drop table(:users)

    drop_if_exists unique_index(:playlist_accesses, [:playlist_id, :user_id],
                     name: "playlist_accesses_playlist_and_user_index"
                   )

    drop table(:playlist_accesses)

    alter table(:content_requests) do
      remove :best_source_request_id
    end

    drop_if_exists unique_index(:content_requests, [:content_id],
                     name: "content_requests_unique_content_index"
                   )

    drop table(:content_requests)

    drop table(:video_tracks)

    drop table(:audio_tracks)

    drop_if_exists index(:participants, [:user_id])

    alter table(:participants) do
      remove :last_read_message_id
    end

    drop_if_exists unique_index(:participants, [:conversation_id, :user_id],
                     name: "participants_user_in_conversation_index"
                   )

    drop table(:participants)

    drop_if_exists unique_index(:media_source_requests, [:content_id, :media_source_id],
                     name: "media_source_requests_unique_content_source_index"
                   )

    drop table(:media_source_requests)

    drop_if_exists unique_index(:tv_show_episodes, [:tv_show_id, :season_number, :episode_number],
                     name: "tv_show_episodes_unique_position_per_tv_show_index"
                   )

    drop table(:tv_show_episodes)

    alter table(:media_sources) do
      remove :updated_at
      remove :inserted_at
      remove :media_type
      remove :source_type
      remove :name
    end

    drop constraint(:servarr_media_sources, "servarr_media_sources_id_fkey")

    alter table(:servarr_media_sources) do
      modify :id, :uuid
    end

    drop table(:media_sources)

    alter table(:movies) do
      remove :backdrop_path
    end

    drop_if_exists unique_index(:movies, [:id], name: "movies_unique_content_index")

    drop table(:movies)

    drop table(:servarr_media_sources)

    drop_if_exists index(:conversations, [:content_id])

    alter table(:conversations) do
      remove :recommended_by_id
      remove :content_id
      remove :inserted_at
    end

    alter table(:messages) do
      modify :conversation_id, :uuid
    end

    drop table(:conversations)

    drop table(:playbacks)

    drop table(:playback_sessions)

    drop_if_exists index(:messages, [:conversation_id, :id])

    drop table(:messages)
    execute(
      "DROP FUNCTION IF EXISTS uuid_generate_v7(), ash_raise_error(jsonb), ash_raise_error(jsonb, ANYCOMPATIBLE), ash_elixir_and(BOOLEAN, ANYCOMPATIBLE), ash_elixir_and(ANYCOMPATIBLE, ANYCOMPATIBLE), ash_elixir_or(ANYCOMPATIBLE, ANYCOMPATIBLE), ash_elixir_or(BOOLEAN, ANYCOMPATIBLE), ash_trim_whitespace(text[]), ash_required(ANYCOMPATIBLE, jsonb)"
    )

  end
end
