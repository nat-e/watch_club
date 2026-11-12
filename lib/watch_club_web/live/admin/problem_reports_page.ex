defmodule WatchClubWeb.Admin.ProblemReportsPage do
  @moduledoc """
  The Problem Reports Users sent from the Player, newest first, beside the one open: the open
  ones, or the archived ones with `?archived=true`. Narrow screens show the list or the report.
  Without open Problem Reports, the page is one empty state.
  """
  use WatchClubWeb, :live_view

  import WatchClubWeb.Components.Accounts.UserAvatar
  import WatchClubWeb.Components.Contents.TmdbPoster
  import WatchClubWeb.Components.Playbacks.ProblemCategory

  alias WatchClub.Playbacks
  alias WatchClub.Playbacks.ProblemReport
  alias WatchClubWeb.Helpers.KeysetStreamState

  @page_size 30

  # What a row and the open report show: the Video, and who reported it
  @report_load [
    playback: [
      session: [:started_by],
      media: [
        video: [
          parts: [
            movie: [:best_localization],
            sports_event: [],
            tv_show_episode: [tv_show: [:best_localization]]
          ]
        ]
      ]
    ]
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_url={@current_url}
      current_user={@current_user}
      instance_settings={@instance_settings}
      playback_session={@playback_session}
      title={dgettext("nav", "Problem reports")}
      space="none"
      class="p-0!"
    >
      <:parent
        :if={@opened_id}
        navigate={list_path(@archived?)}
        label={list_title(@archived?)}
        patch
        narrow_only
      />

      <div :if={!@first_report and !@archived?} class="px-page py-page-y">
        <.empty id="no-problem-reports">
          <:icon><Lucideicons.flag /></:icon>
          <:title>{dgettext("admin_problem_reports", "No open reports")}</:title>
          <:description>
            {dgettext(
              "admin_problem_reports",
              "When friends report a problem from the Player, it shows up here, with what the Player showed at that moment."
            )}
          </:description>
          <.button
            :if={@any_archived?}
            id="no-problem-reports-archived"
            variant="secondary"
            patch={list_path(true)}
          >
            <:icon><Lucideicons.archive /></:icon>
            {list_title(true)}
          </.button>
        </.empty>
      </div>

      <.split_view :if={@first_report || @archived?} open={@opened_id != nil}>
        <:list>
          <div class="flex items-center gap-tight px-related max-md:pt-group">
            <.button
              :if={@archived?}
              id="show-open-problem-reports"
              variant="ghost"
              size="icon-sm"
              patch={list_path(false)}
              aria-label={dgettext("admin_problem_reports", "Back to open reports")}
            >
              <Lucideicons.arrow_left />
            </.button>
            <h2 class={["flex-1 text-xs", !@archived? && "px-related"]}>
              <.text_label text={list_title(@archived?)} />
            </h2>
            <.dropdown_menu :if={!@archived?} id="problem-reports-menu">
              <:trigger>
                <.button
                  id="problem-reports-menu-button"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={dgettext("admin_problem_reports", "More")}
                >
                  <Lucideicons.ellipsis />
                </.button>
              </:trigger>
              <.dropdown_menu_item id="show-archived-problem-reports" patch={list_path(true)}>
                <Lucideicons.archive /> {list_title(true)}
              </.dropdown_menu_item>
            </.dropdown_menu>
          </div>

          <ul id="problem-reports" phx-update="stream" class="flex flex-col gap-px px-related">
            <li :for={{dom_id, report} <- @streams.reports} id={dom_id}>
              <.report_row
                report={report}
                patch={report_path(report, @archived?)}
                selected={@shown != nil and @shown.id == report.id}
                locale={@current_user.settings.locale}
              />
            </li>
          </ul>
          <p :if={!@first_report} class="px-group text-sm text-text-muted">
            {dgettext("admin_problem_reports", "No archived reports")}
          </p>
          <.infinite_scroll_trigger
            :if={KeysetStreamState.can_load_more?(@reports_state)}
            id="problem-reports-load-more"
            event="load_more_reports"
          />
        </:list>

        <:detail>
          <.report_detail
            :if={@shown}
            report={@shown}
            locale={@current_user.settings.locale}
          />
        </:detail>
      </.split_view>
    </Layouts.app>
    """
  end

  attr :report, ProblemReport, required: true
  attr :patch, :string, required: true
  attr :selected, :boolean, required: true, doc: "highlighted where the list shows beside it"
  attr :locale, :atom, required: true

  # The poster, the Video and what's wrong, then when it was reported and by whom
  defp report_row(assigns) do
    assigns = assign(assigns, about(assigns.report))

    ~H"""
    <.link
      id={"problem-report-#{@report.id}-link"}
      patch={@patch}
      aria-current={@selected && "true"}
      class="flex items-center gap-group rounded-control p-related transition-colors hover:bg-surface-hover @split-view/main:aria-[current=true]:bg-surface-selected"
    >
      <.tmdb_poster path={@poster_path} size="w154" class="w-12 shrink-0" />
      <div class="flex min-w-0 flex-1 flex-col gap-tight">
        <span class="truncate font-semibold">{@title}{@episode && " #{@episode}"}</span>
        <.problem_category category={@report.category} class="text-sm" />
      </div>
      <div class="flex shrink-0 flex-col items-end gap-tight text-xs">
        <span class="text-text-subtle">{Time.relative_from_now(@report.inserted_at, @locale)}</span>
        <span class="flex items-center gap-tight text-text-muted">
          <.user_avatar user={@reporter} size="xs" />{username(@reporter)}
        </span>
      </div>
    </.link>
    """
  end

  attr :report, ProblemReport, required: true
  attr :locale, :atom, required: true

  # The Video, Play at the reported time and Archive, then what's wrong and what the Player
  # showed. A report without a time was sent before the Video loaded.
  defp report_detail(assigns) do
    assigns = assign(assigns, about(assigns.report))

    ~H"""
    <section
      aria-labelledby="problem-report-title"
      class="flex max-w-3xl min-w-0 flex-col gap-cluster px-page pb-page-y md:pt-group"
    >
      <header class="flex flex-col gap-group @xl:flex-row @xl:items-center @xl:justify-between">
        <div class="flex min-w-0 items-center gap-group">
          <.tmdb_poster path={@poster_path} size="w154" class="w-16 shrink-0" />
          <div class="flex min-w-0 flex-col gap-tight">
            <h2 id="problem-report-title" class="font-heading text-xl font-semibold">{@title}</h2>
            <p :if={@episode} class="text-text-muted">{@episode}</p>
          </div>
        </div>
        <div class="flex shrink-0 flex-wrap gap-related">
          <.button
            :if={@report.position_seconds}
            id="problem-report-play"
            variant="secondary"
            navigate={~p"/play/#{@report.playback.media_id}?#{[t: trunc(@report.position_seconds)]}"}
          >
            <:icon><Lucideicons.play /></:icon>
            {dgettext("admin_problem_reports", "Play at %{time}",
              time: Time.position(@report.position_seconds)
            )}
          </.button>
          <.button
            :if={!@report.archived_at}
            id="problem-report-archive"
            variant="secondary"
            phx-click="archive"
          >
            <:icon><Lucideicons.archive /></:icon>
            {dgettext("admin_problem_reports", "Archive")}
          </.button>
        </div>
      </header>

      <div class="flex flex-col gap-tight">
        <.problem_category category={@report.category} class="font-semibold" />
        <p :if={@report.comment} class="max-w-readable text-text-muted">
          <span class="whitespace-pre-line">{@report.comment}</span>
        </p>
      </div>

      <.card padding="group">
        <dl class="grid grid-cols-[auto_1fr] items-baseline gap-x-group gap-y-related text-sm">
          <dt class="text-text-muted">{dgettext("admin_problem_reports", "Reported by")}</dt>
          <dd class="flex min-w-0 items-center gap-related self-center">
            <.user_avatar user={@reporter} size="xs" />
            <span class="truncate">
              {dgettext("admin_problem_reports", "%{username}, %{time}",
                username: username(@reporter),
                time: Time.relative_from_now(@report.inserted_at, @locale)
              )}
            </span>
          </dd>
          <dt class="text-text-muted">{dgettext("admin_problem_reports", "Time in video")}</dt>
          <dd class="tabular-nums">
            {if @report.position_seconds,
              do: Time.position(@report.position_seconds),
              else: dgettext("admin_problem_reports", "Didn't load")}
          </dd>
          <%= if @report.position_seconds do %>
            <dt class="text-text-muted">{dgettext("admin_problem_reports", "Audio")}</dt>
            <dd>{@report.audio}</dd>
            <dt class="text-text-muted">{dgettext("admin_problem_reports", "Subtitles")}</dt>
            <dd>{@report.subtitles || dgettext("admin_problem_reports", "Off")}</dd>
            <dt class="text-text-muted">{dgettext("admin_problem_reports", "Quality")}</dt>
            <dd>{@report.quality}</dd>
          <% end %>
          <dt class="text-text-muted">{dgettext("admin_problem_reports", "Device")}</dt>
          <dd class="break-words">{@report.user_agent}</dd>
          <%= if @report.archived_at do %>
            <dt class="text-text-muted">{dgettext("admin_problem_reports", "Archived")}</dt>
            <dd>{Time.relative_from_now(@report.archived_at, @locale)}</dd>
          <% end %>
        </dl>
      </.card>
    </section>
    """
  end

  # The title, the episode number and the poster of the Video, and the User who reported it.
  # Refresh Metadata can leave the Video Unmatched Media, named by its file.
  defp about(%ProblemReport{playback: %{session: %{started_by: reporter}, media: media}}) do
    {title, episode, poster_path} =
      case Video.work(media.video) do
        %Movie{best_localization: localization} ->
          {localization.title, nil, localization.poster_path}

        %SportsEvent{} = event ->
          {event.title, nil, event.poster_url}

        %TvShowEpisode{tv_show: tv_show} = episode ->
          {tv_show.best_localization.title, episode.formatted_episode_number,
           tv_show.best_localization.poster_path}

        nil ->
          {Path.basename(media.path), nil, nil}
      end

    %{title: title, episode: episode, poster_path: poster_path, reporter: reporter}
  end

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, stream_configure(socket, :reports, dom_id: &"problem-report-#{&1.id}")}

  @impl true
  def handle_params(params, _uri, socket) do
    archived? = params["archived"] == "true"
    opened_id = params["problem_report_id"]

    if socket.assigns[:archived?] == archived? do
      previous = socket.assigns.shown
      socket = show_report(socket, opened_id)

      # The rows of the reports closed and opened render again, to show which one is open
      case {previous, socket.assigns.shown} do
        {%{id: id}, %{id: id}} ->
          {:noreply, socket}

        {previous, shown} ->
          {:noreply,
           [previous, shown]
           |> Enum.reject(&is_nil/1)
           |> Enum.reduce(socket, &stream_insert(&2, :reports, &1, update_only: true))}
      end
    else
      {:noreply, socket |> list_reports!(archived?) |> show_report(opened_id)}
    end
  end

  @impl true
  def handle_event("load_more_reports", _params, socket) do
    if KeysetStreamState.can_load_more?(socket.assigns.reports_state),
      do: {:noreply, load_reports_page!(socket)},
      else: {:noreply, socket}
  end

  def handle_event("archive", _params, socket) do
    Playbacks.archive_problem_report!(socket.assigns.shown, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, dgettext("admin_problem_reports", "Report archived."))
     |> list_reports!(false)
     |> push_patch(to: list_path(false))}
  end

  # The first page of the open or the archived reports, with the newest shown, and whether there
  # are archived ones for the empty state
  defp list_reports!(socket, archived?) do
    socket =
      socket
      |> assign(archived?: archived?, reports_state: KeysetStreamState.init(@page_size))
      |> load_reports_page!()

    %{first_report: first_report, current_user: user} = socket.assigns

    any_archived? =
      !archived? and !first_report and
        Playbacks.list_problem_reports!(true, page: [limit: 1], actor: user).results != []

    assign(socket, shown: first_report, opened_id: nil, any_archived?: any_archived?)
  end

  defp load_reports_page!(socket) do
    %{reports_state: state, archived?: archived?, current_user: user} = socket.assigns

    {:ok, new_state, reports} =
      KeysetStreamState.load_page(state, fn page ->
        Playbacks.list_problem_reports(archived?, load: @report_load, page: page, actor: user)
      end)

    socket = assign(socket, :reports_state, new_state)

    if state.status == :init,
      do:
        socket
        |> assign(:first_report, List.first(reports))
        |> stream(:reports, reports, reset: true),
      else: stream(socket, :reports, reports)
  end

  # The report in the URL, else the newest, which wide screens show beside the list
  defp show_report(socket, nil),
    do: assign(socket, shown: socket.assigns.first_report, opened_id: nil)

  defp show_report(socket, id) do
    case Playbacks.get_problem_report_by_id(id,
           load: @report_load,
           actor: socket.assigns.current_user
         ) do
      {:ok, report} ->
        assign(socket, shown: report, opened_id: id)

      {:error, _not_found} ->
        socket
        |> put_flash(:error, dgettext("admin_problem_reports", "We couldn't find this report."))
        |> push_patch(to: list_path(socket.assigns.archived?))
    end
  end

  defp list_path(false), do: ~p"/admin/problem-reports"
  defp list_path(true), do: ~p"/admin/problem-reports?#{[archived: true]}"

  defp report_path(report, false), do: ~p"/admin/problem-reports/#{report.id}"
  defp report_path(report, true), do: ~p"/admin/problem-reports/#{report.id}?#{[archived: true]}"

  defp list_title(false), do: dgettext("admin_problem_reports", "Open reports")
  defp list_title(true), do: dgettext("admin_problem_reports", "Archived reports")
end
