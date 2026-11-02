defmodule WatchClubWeb.Components.Requests.RequestCard do
  @moduledoc """
  Request card for the My Requests page.

  Takes the `ContentRequest` (with `content`, `status`, `progress` and
  `has_media?` loaded) plus the viewer's `locale`, and lays out a flex row of
  two sections:

    - Left (Content): poster with a Play overlay when `playable` (independent of
      status), then the content-type badge, title, year, and an "Add to Library"
      button revealed on card hover (or focus-within).
    - Right (Status): fixed-width tinted panel headed by the status'
      `translated_label`, with a cancel/delete icon, the status body (a progress
      bar for the three in-progress statuses), and "Requested X ago".

  Status is grouped by color: `not_released`/`not_found` gray, the in-flight
  trio (`requested`/`downloading`/`importing`) accent, `failed` danger,
  `completed` success.
  """
  use WatchClubWeb, :component

  import WatchClubWeb.Components.Contents.ContentTypeBadge
  import WatchClubWeb.Components.Contents.TmdbPoster

  alias WatchClubWeb.Components.Contents.PlayOrRequestButtonLive

  attr :id, :string
  attr :request, ContentRequest, required: true
  attr :current_user, User, required: true

  def request_card(assigns) do
    ~H"""
    <.card
      as="article"
      data_slot="request-card"
      padding="none"
      id={@id}
      class="flex flex-col @xl:flex-row"
    >
      <.content_section
        id={@request.id}
        content={@request.content}
        current_user={@current_user}
      />

      <.status_section request={@request} current_user={@current_user} />
    </.card>
    """
  end

  # ─── Content section ─────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :content, Content, required: true
  attr :current_user, User, required: true

  defp content_section(assigns) do
    assigns = assigns |> assign(content_identity: ContentIdentity.from_content(assigns.content))

    ~H"""
    <div class={[
      "relative flex flex-1 items-center gap-group p-group",
      !@content.has_media? && "opacity-70"
    ]}>
      <.tmdb_poster
        size="w342"
        path={@content.implementation.best_localization.poster_path}
        class="h-36 shrink-0 border border-border-subtle shadow-overlay"
      />

      <div class="flex flex-1 flex-col justify-between gap-related h-full overflow-clip">
        <.stack space="tight">
          <.content_type_badge type={@content.type} />
          <.link
            href={Url.content_details_link(@content)}
            class="line-clamp-2 text-xl font-semibold tracking-tight after:absolute after:inset-0 after:content-['']"
          >
            {@content.implementation.best_localization.title}
          </.link>
          <p :if={@content.release_date} class="text-sm text-text-muted">
            {@content.release_date.year}
          </p>
        </.stack>

        <.cluster space="related">
          <.live_component
            id={PlayOrRequestButtonLive.dom_id(@content_identity)}
            module={PlayOrRequestButtonLive}
            play_only={true}
            content_identity={@content_identity}
            current_user={@current_user}
            class="z-10"
          />
          <.button
            id={"share-button-#{@content.id}"}
            variant="accent"
            phx-click="open_add_to_library_modal"
            phx-value-content_id={@content.id}
            class="z-10"
          >
            <:icon><Lucideicons.share_2 /></:icon>
            {dgettext("requests", "Share with a club")}
          </.button>
        </.cluster>
      </div>
    </div>
    """
  end

  attr :request, ContentRequest, required: true
  attr :current_user, User, required: true

  defp status_section(%{request: %ContentRequest{status_group: :completed}} = assigns) do
    ~H"""
    <.generic_status_section
      variant="success"
      status_label={dgettext("requests", "Completed")}
      text={dgettext("requests", "Your content is ready to watch!")}
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(
         %{
           request: %ContentRequest{
             best_source_request: %MediaSourceRequest{status: :downloading}
           }
         } = assigns
       ) do
    ~H"""
    <.generic_status_section
      variant="accent"
      status_label={dgettext("requests", "Downloading")}
      progress={round(@request.best_source_request.download_progress)}
      text={dgettext("requests", "Your content is being downloaded")}
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(
         %{
           request: %ContentRequest{best_source_request: %MediaSourceRequest{status: :downloaded}}
         } = assigns
       ) do
    ~H"""
    <.generic_status_section
      variant="accent"
      status_label={dgettext("requests", "Almost ready")}
      progress={100}
      text={dgettext("requests", "Your content has been downloaded and is being imported")}
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(
         %{
           request: %ContentRequest{
             best_source_request: %MediaSourceRequest{status: :not_released}
           }
         } = assigns
       ) do
    ~H"""
    <.generic_status_section
      variant="default"
      status_label={dgettext("requests", "Not released")}
      text={
        dgettext(
          "requests",
          "Your content is not available yet. We will download it automatically as soon as it's released!"
        )
      }
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(
         %{
           request: %ContentRequest{
             best_source_request: %MediaSourceRequest{status: :needs_attention}
           }
         } = assigns
       ) do
    ~H"""
    <.generic_status_section
      variant="danger"
      progress={round(@request.best_source_request.download_progress)}
      status_label={dgettext("requests", "Needs attention")}
      text={
        dgettext(
          "requests",
          "There was a problem with this request that requires human attention. The administrator has been informed."
        )
      }
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(
         %{request: %ContentRequest{percent_imported: percent_imported}} =
           assigns
       )
       when percent_imported > 0 do
    ~H"""
    <.generic_status_section
      variant="accent"
      status_label={dgettext("requests", "Missing episodes")}
      progress={round(@request.percent_imported)}
      text={
        dgettext(
          "requests",
          "We couldn't find some episodes of your show. We will keep looking for them."
        )
      }
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(%{request: %ContentRequest{best_source_request: nil}} = assigns) do
    ~H"""
    <.generic_status_section
      variant="accent"
      status_label={dgettext("requests", "Requested")}
      text={
        dgettext(
          "requests",
          "The administrator has been informed of your request. You will be notified when this content is ready."
        )
      }
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  defp status_section(%{request: %ContentRequest{status_group: :not_found}} = assigns) do
    ~H"""
    <.generic_status_section
      variant="default"
      status_label={dgettext("requests", "Not found")}
      text={
        dgettext(
          "requests",
          "Your content has not been found yet. It will be downloaded automatically when we find it."
        )
      }
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  # Searching and recent
  defp status_section(assigns) do
    ~H"""
    <.generic_status_section
      variant="accent"
      status_label={dgettext("requests", "Searching")}
      text={dgettext("requests", "We are looking for your content...")}
      request={@request}
      locale={@current_user.settings.locale}
    />
    """
  end

  attr :request, ContentRequest, required: true
  attr :status_label, :string, required: true
  attr :text, :string, required: true
  attr :progress, :integer, default: nil
  attr :variant, :string, values: ~w(default accent danger success)
  attr :locale, :atom, required: true

  def generic_status_section(assigns) do
    ~H"""
    <div class={[
      "order-first flex flex-col justify-between gap-related border-b p-group rounded-t-xl @xl:rounded-t-none @xl:rounded-r-xl @xl:order-0 @xl:w-64 @xl:border-b-0 @xl:border-l",
      @variant == "default" && ["bg-surface-inset border-border-subtle"],
      @variant == "accent" && ["bg-accent-bg border-accent-border"],
      @variant == "danger" && ["bg-danger-bg border-danger-border"],
      @variant == "success" && ["bg-success-bg border-success-border"]
    ]}>
      <div class="flex items-center justify-between gap-related">
        <p class={[
          "text-sm font-semibold tracking-wider uppercase",
          @variant == "default" && ["text-text-muted"],
          @variant == "accent" && ["text-accent"],
          @variant == "danger" && ["text-danger"],
          @variant == "success" && ["text-success"]
        ]}>
          {@status_label}
        </p>
        <.button
          id={"#{@request.id}-cancel"}
          variant="ghost"
          size="icon-sm"
          aria-label={dgettext("requests", "Cancel request")}
          phx-click="cancel-request"
          phx-value-id={@request.id}
        >
          <Lucideicons.trash_2 />
        </.button>
      </div>

      <.stack space="tight">
        <div class="flex items-baseline justify-between">
          <p class="text-sm font-medium text-text">{@text}</p>
          <p :if={!is_nil(@progress)} class="text-xs tabular-nums">
            {@progress}%
          </p>
        </div>
        <div
          :if={!is_nil(@progress)}
          class="h-1.5 w-full overflow-hidden rounded-full bg-surface-inset"
          role="progressbar"
          aria-valuenow={@progress}
          aria-valuemin="0"
          aria-valuemax="100"
          aria-label={@text}
        >
          <div
            class="h-full bg-accent transition-[width]"
            style={"width: #{@progress}%"}
            aria-hidden="true"
          >
          </div>
        </div>
      </.stack>

      <p class="text-xs text-text-muted">
        {dgettext("requests", "Requested %{relative_time}",
          relative_time: Time.relative_from_now(@request.inserted_at, @locale)
        )}
      </p>
    </div>
    """
  end
end
