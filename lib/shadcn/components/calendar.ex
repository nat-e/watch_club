defmodule Shadcn.Components.Calendar do
  @moduledoc """
  Month-grid date picker.

  Self-contained: a JS hook owns navigation and selection, and dispatches
  `input`/`change` on a hidden `<input>` so the value lifts cleanly into
  Phoenix forms (no `phx-click` handlers required on the parent LV).

      <.calendar id="picker" name="when" />
      <.calendar id="picker" name="when" value={~D[2026-04-28]} />
      <.calendar id="picker" mode="range"
                 value={%{from: ~D[2026-04-10], to: ~D[2026-04-20]}} />
      <.calendar id="picker" caption_layout="dropdown" />
      <.calendar id="picker" disabled_dates={[~D[2026-04-30]]} />
      <.calendar id="picker" show_week_numbers />

  Range mode emits two hidden inputs (`name[from]` / `name[to]`), so it
  round-trips through Phoenix nested params.

  Date + time composition — pair a calendar with an `<.input type="time">`
  bound to the same form. Programmatic updates — dispatch a `calendar:set`
  event on the root with `{date: iso}` (single) or `{from: iso, to: iso}`
  (range).

  Differences from the React port:
  - Caption dropdowns are plain native `<select>` elements (no extra JS).
  - Time picker / presets / custom cell size are callsite recipes, not
    built into the component.
  - No RTL, no Hijri/Persian.

  Ported from Shadcn on 2026-04-29
  Commit: 7d718ddaa9c32b9c3d489bc3f6ca3994bf049570
  Source: https://github.com/shadcn-ui/ui/blob/7d718ddaa9c32b9c3d489bc3f6ca3994bf049570/apps/v4/styles/radix-vega/ui/calendar.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/calendar
  """
  use Phoenix.Component

  @weekday_labels ~w(Mo Tu We Th Fr Sa Su)
  @month_names ~w(January February March April May June July August September October November December)

  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :name, :any, default: nil
  attr :mode, :string, values: ~w(single range), default: "single"

  attr :value, :any,
    default: nil,
    doc: ~s|`Date`/ISO for single; `%{from: _, to: _}` (or tuple) for range|

  attr :month, :any,
    default: nil,
    doc: "month to display (Date or ISO string); defaults to value or today"

  attr :caption_layout, :string,
    values: ~w(label dropdown dropdown-months dropdown-years),
    default: "label"

  attr :from_year, :integer, default: nil
  attr :to_year, :integer, default: nil
  attr :disabled_dates, :list, default: []
  attr :show_outside_days, :boolean, default: true
  attr :show_week_numbers, :boolean, default: false
  attr :rest, :global

  def calendar(assigns) do
    today = Date.utc_today()
    {from_date, to_date} = parse_value(assigns.mode, assigns.value)
    seed = parse_date(assigns.month) || from_date || today
    month = Date.beginning_of_month(seed)
    weeks = build_grid(month)
    disabled_set = parse_disabled(assigns.disabled_dates)
    from_year = assigns.from_year || today.year - 100
    to_year = assigns.to_year || today.year + 10
    months_list = Enum.with_index(@month_names, 1) |> Enum.map(fn {n, i} -> {i, n} end)

    assigns =
      assigns
      |> assign(:month, month)
      |> assign(:weeks, weeks)
      |> assign(:today, today)
      |> assign(:from_date, from_date)
      |> assign(:to_date, to_date)
      |> assign(:disabled_set, disabled_set)
      |> assign(:disabled_json, disabled_set |> Enum.map(&Date.to_iso8601/1) |> Jason.encode!())
      |> assign(:month_names, @month_names)
      |> assign(:month_names_json, Jason.encode!(@month_names))
      |> assign(:weekday_labels, @weekday_labels)
      |> assign(:months_list, months_list)
      |> assign(:years_range, from_year..to_year)
      |> assign(:from_year, from_year)
      |> assign(:to_year, to_year)

    ~H"""
    <div
      id={@id}
      data-slot="calendar"
      data-mode={@mode}
      data-month={Date.to_iso8601(@month)}
      data-caption-layout={@caption_layout}
      data-show-outside-days={(@show_outside_days && "true") || "false"}
      data-show-week-numbers={(@show_week_numbers && "true") || "false"}
      data-from-year={@from_year}
      data-to-year={@to_year}
      data-disabled-dates={@disabled_json}
      data-month-names={@month_names_json}
      phx-hook="CalendarHook"
      class={["group/calendar", @class]}
      {@rest}
    >
      <input
        :if={@mode == "single"}
        type="hidden"
        data-slot="calendar-input"
        name={@name}
        value={(@from_date && Date.to_iso8601(@from_date)) || ""}
      />
      <input
        :if={@mode == "range"}
        type="hidden"
        data-slot="calendar-input"
        data-range="from"
        name={@name && "#{@name}[from]"}
        value={(@from_date && Date.to_iso8601(@from_date)) || ""}
      />
      <input
        :if={@mode == "range"}
        type="hidden"
        data-slot="calendar-input"
        data-range="to"
        name={@name && "#{@name}[to]"}
        value={(@to_date && Date.to_iso8601(@to_date)) || ""}
      />

      <div data-slot="calendar-nav">
        <button
          type="button"
          data-slot="calendar-nav-button"
          data-direction="prev"
          aria-label="Previous month"
        >
          <Lucideicons.chevron_left />
        </button>
        <div data-slot="calendar-caption" data-layout={@caption_layout}>
          <span
            :if={@caption_layout in ~w(label dropdown-years)}
            data-slot="calendar-caption-month-label"
          >
            {Enum.at(@month_names, @month.month - 1)}
          </span>
          <div
            :if={@caption_layout in ~w(dropdown dropdown-months)}
            data-slot="calendar-caption-dropdown"
          >
            <select data-slot="calendar-caption-select" data-axis="month" aria-label="Month">
              <option :for={{i, name} <- @months_list} value={i} selected={i == @month.month}>
                {name}
              </option>
            </select>
            <Lucideicons.chevron_down data-slot="calendar-caption-chevron" aria-hidden="true" />
          </div>
          <span
            :if={@caption_layout in ~w(label dropdown-months)}
            data-slot="calendar-caption-year-label"
          >
            {@month.year}
          </span>
          <div
            :if={@caption_layout in ~w(dropdown dropdown-years)}
            data-slot="calendar-caption-dropdown"
          >
            <select data-slot="calendar-caption-select" data-axis="year" aria-label="Year">
              <option :for={y <- @years_range} value={y} selected={y == @month.year}>{y}</option>
            </select>
            <Lucideicons.chevron_down data-slot="calendar-caption-chevron" aria-hidden="true" />
          </div>
        </div>
        <button
          type="button"
          data-slot="calendar-nav-button"
          data-direction="next"
          aria-label="Next month"
        >
          <Lucideicons.chevron_right />
        </button>
      </div>

      <table data-slot="calendar-table">
        <thead>
          <tr>
            <th
              :if={@show_week_numbers}
              data-slot="calendar-week-number-header"
              aria-label="Week number"
            >
              #
            </th>
            <th :for={d <- @weekday_labels} data-slot="calendar-weekday">{d}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={week <- @weeks}>
            <td :if={@show_week_numbers} data-slot="calendar-week-number">
              {iso_week_number(List.first(week))}
            </td>
            <td :for={day <- week} data-slot="calendar-cell">
              <button
                type="button"
                data-slot="calendar-day"
                data-date={Date.to_iso8601(day)}
                data-outside={(day_outside?(day, @month) && "true") || nil}
                data-today={(Date.compare(day, @today) == :eq && "true") || nil}
                data-disabled={(MapSet.member?(@disabled_set, day) && "true") || nil}
                data-selected-single={day_selected_single(@mode, day, @from_date)}
                data-range-start={day_range_start(@mode, day, @from_date)}
                data-range-end={day_range_end(@mode, day, @to_date)}
                data-range-middle={day_range_middle(@mode, day, @from_date, @to_date)}
                aria-label={Calendar.strftime(day, "%A %B %-d, %Y")}
                aria-disabled={(MapSet.member?(@disabled_set, day) && "true") || nil}
                aria-pressed={day_aria_pressed(@mode, day, @from_date, @to_date)}
                tabindex="-1"
              >
                {day.day}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(%Date{} = date), do: date
  defp parse_date(iso) when is_binary(iso), do: Date.from_iso8601!(iso)

  defp parse_value("single", v), do: {parse_date(v), nil}
  defp parse_value("range", nil), do: {nil, nil}

  defp parse_value("range", %{from: f, to: t}), do: {parse_date(f), parse_date(t)}

  defp parse_value("range", %{"from" => f, "to" => t}),
    do: {parse_date(f), parse_date(t)}

  defp parse_value("range", {f, t}), do: {parse_date(f), parse_date(t)}

  defp parse_disabled(list) when is_list(list) do
    list |> Enum.map(&parse_date/1) |> Enum.reject(&is_nil/1) |> MapSet.new()
  end

  defp build_grid(month_first) do
    last = Date.end_of_month(month_first)
    grid_start = Date.add(month_first, -(Date.day_of_week(month_first) - 1))

    0..41
    |> Enum.map(&Date.add(grid_start, &1))
    |> Enum.chunk_every(7)
    |> Enum.take_while(fn week ->
      Enum.any?(week, fn d -> Date.compare(d, last) != :gt end)
    end)
  end

  defp day_outside?(day, month_first) do
    Date.compare(day, month_first) == :lt or
      Date.compare(day, Date.end_of_month(month_first)) == :gt
  end

  defp day_selected_single("single", day, from) when not is_nil(from) do
    if Date.compare(day, from) == :eq, do: "true", else: nil
  end

  defp day_selected_single(_, _, _), do: nil

  defp day_range_start("range", day, from) when not is_nil(from) do
    if Date.compare(day, from) == :eq, do: "true", else: nil
  end

  defp day_range_start(_, _, _), do: nil

  defp day_range_end("range", day, to) when not is_nil(to) do
    if Date.compare(day, to) == :eq, do: "true", else: nil
  end

  defp day_range_end(_, _, _), do: nil

  defp day_range_middle("range", day, from, to) when not is_nil(from) and not is_nil(to) do
    if Date.compare(day, from) == :gt and Date.compare(day, to) == :lt,
      do: "true",
      else: nil
  end

  defp day_range_middle(_, _, _, _), do: nil

  defp day_aria_pressed("single", day, from, _to), do: bool_str(day_eq?(day, from))

  defp day_aria_pressed("range", day, from, to),
    do: bool_str(day_eq?(day, from) or day_eq?(day, to) or in_range?(day, from, to))

  defp day_aria_pressed(_, _, _, _), do: "false"

  defp day_eq?(_, nil), do: false
  defp day_eq?(day, other), do: Date.compare(day, other) == :eq

  defp in_range?(_, nil, _), do: false
  defp in_range?(_, _, nil), do: false

  defp in_range?(day, from, to),
    do: Date.compare(day, from) == :gt and Date.compare(day, to) == :lt

  defp bool_str(true), do: "true"
  defp bool_str(false), do: "false"

  defp iso_week_number(date) do
    {_year, week} = :calendar.iso_week_number(Date.to_erl(date))
    week
  end
end
