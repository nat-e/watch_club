defmodule WatchClub.Playbacks.ProblemReport do
  @moduledoc """
  What a User reports from the Player about the Video of their Playback: what's wrong, an
  optional comment, and what the Player showed then. The Playback gives the User, the Video and
  the Content. Only the Instance Administrator reads and archives Problem Reports.
  """

  use Ash.Resource,
    otp_app: :watch_club,
    domain: WatchClub.Playbacks,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  use Gettext, backend: WatchClubWeb.Gettext

  alias WatchClub.Playbacks.Playback
  alias WatchClub.Playbacks.ProblemReport.Category

  postgres do
    table "problem_reports"
    repo WatchClub.Repo

    references do
      reference :playback, on_delete: :delete, index?: true
    end
  end

  actions do
    defaults [:read]

    create :report do
      description "Report a Problem with the Video of one of the actor's Playbacks."

      accept [
        :playback_id,
        :category,
        :comment,
        :position_seconds,
        :audio,
        :subtitles,
        :quality,
        :user_agent
      ]
    end

    read :list do
      description "The open or the archived Problem Reports, newest first."
      argument :archived?, :boolean, allow_nil?: false

      filter expr(if ^arg(:archived?), do: not is_nil(archived_at), else: is_nil(archived_at))
      prepare build(sort: [inserted_at: :desc])
      pagination keyset?: true, required?: false
    end

    update :archive do
      description "Set a handled Problem Report aside, without telling its User."
      accept []

      change set_attribute(:archived_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action(:report) do
      description "Users report Problems about their own Playbacks"
      authorize_if expr(playback.session.started_by_id == ^actor(:id))
    end

    policy action_type([:read, :update]) do
      description "Only the Instance Administrator reads and archives Problem Reports"
      authorize_if actor_attribute_equals(:administrator?, true)
    end
  end

  validations do
    validate present(:category) do
      on [:create]
      message dgettext_noop("errors", "Pick what's wrong")
    end

    validate string_length(:comment, max: 1000) do
      message dgettext_noop("errors", "Details cannot be longer than %{max} characters")
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # The validations own the user-facing message
    attribute :category, Category do
      allow_nil? false
      public? true
    end

    attribute :comment, :string do
      public? true
    end

    attribute :position_seconds, :float do
      description "Where the Video was, or nil when it never played."
      public? true
    end

    attribute :audio, :string do
      description "The Audio Track the Player showed."
      public? true
    end

    attribute :subtitles, :string do
      description "The Text Track the Player showed, or nil without subtitles."
      public? true
    end

    attribute :quality, :string do
      description "The quality the Player showed, such as \"Auto, 720p\"."
      public? true
    end

    attribute :user_agent, :string do
      public? true
    end

    attribute :archived_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :playback, Playback do
      allow_nil? false
      public? true
    end
  end
end
