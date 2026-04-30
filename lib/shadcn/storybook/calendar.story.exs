defmodule Shadcn.Storybook.Calendar do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Calendar

  def function, do: &Calendar.calendar/1

  def imports,
    do: [
      {Shadcn.Components.Button, [button: 1]},
      {Shadcn.Components.Card, [card: 1]},
      {Shadcn.Components.Field, [field: 1, field_label: 1, field_group: 1]},
      {Shadcn.Components.InputGroup, [input_group: 1, input_group_input: 1, input_group_addon: 1]}
    ]

  def template do
    """
    <div class="flex items-start justify-center p-12">
      <.psb-variation/>
    </div>
    """
  end

  defp preset_buttons(cal_id) do
    today = Date.utc_today()

    presets = [
      {"Today", today},
      {"Tomorrow", Date.add(today, 1)},
      {"In 3 days", Date.add(today, 3)},
      {"In a week", Date.add(today, 7)},
      {"In 2 weeks", Date.add(today, 14)}
    ]

    Enum.map_join(presets, "\n", fn {label, date} ->
      iso = Date.to_iso8601(date)

      ~s|<.button variant="outline" size="sm" class="flex-1" onclick="document.getElementById('#{cal_id}').dispatchEvent(new CustomEvent('calendar:set',{detail:{date:'#{iso}'}}))">#{label}</.button>|
    end)
  end

  def variations do
    [
      %Variation{
        id: :basic,
        description: "Single-date picker — today is highlighted",
        attributes: %{name: "date"}
      },
      %Variation{
        id: :with_value,
        description: "Single-date picker with an initial selection",
        attributes: %{
          name: "date",
          value: "2026-04-15",
          month: "2026-04-01"
        }
      },
      %Variation{
        id: :range,
        description: "Range mode — click two dates to define a range",
        attributes: %{
          name: "stay",
          mode: "range",
          value: %{from: "2026-04-10", to: "2026-04-20"},
          month: "2026-04-01"
        }
      },
      %Variation{
        id: :dropdown_caption,
        description: "Month and year selectors in the caption",
        attributes: %{
          name: "date",
          caption_layout: "dropdown",
          month: "2026-04-01"
        }
      },
      %Variation{
        id: :booked_dates,
        description: "Disable specific dates (`disabled_dates`)",
        attributes: %{
          name: "date",
          month: "2026-04-01",
          disabled_dates: ["2026-04-10", "2026-04-11", "2026-04-17", "2026-04-18", "2026-04-30"]
        }
      },
      %Variation{
        id: :week_numbers,
        description: "Show ISO week numbers in a leading column",
        attributes: %{
          name: "date",
          show_week_numbers: true,
          month: "2026-04-01"
        }
      },
      %Variation{
        id: :presets,
        description: "Calendar with preset shortcuts in a footer",
        template: """
        <div class="flex items-start justify-center p-12">
          <.card size="sm" class="w-fit">
            <.psb-variation/>
            <:footer class="flex flex-wrap gap-2 border-t">
              #{preset_buttons("calendar-single-presets")}
            </:footer>
          </.card>
        </div>
        """,
        attributes: %{
          name: "date",
          class: "border-0 bg-transparent p-0"
        }
      },
      %Variation{
        id: :datetime,
        description: "Date + start/end time pickers in a card footer",
        template: """
        <div class="flex items-start justify-center p-12">
          <.card size="sm" class="w-fit">
            <.psb-variation/>
            <:footer class="flex-col items-stretch gap-4 border-t">
              <.field>
                <.field_label for="time-from">Start Time</.field_label>
                <.input_group>
                  <.input_group_addon>
                    <Lucideicons.clock class="text-muted-foreground" />
                  </.input_group_addon>
                  <.input_group_input id="time-from" type="time" name="start_time" value="10:30" step="60" />
                </.input_group>
              </.field>
              <.field>
                <.field_label for="time-to">End Time</.field_label>
                <.input_group>
                  <.input_group_addon>
                    <Lucideicons.clock class="text-muted-foreground" />
                  </.input_group_addon>
                  <.input_group_input id="time-to" type="time" name="end_time" value="12:30" step="60" />
                </.input_group>
              </.field>
            </:footer>
          </.card>
        </div>
        """,
        attributes: %{
          name: "date",
          value: "2026-04-12",
          month: "2026-04-01",
          class: "border-0 bg-transparent p-0"
        }
      }
    ]
  end
end
