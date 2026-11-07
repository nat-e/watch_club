defmodule WatchClubWeb.Storybook.Select do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.UI.Select

  def function, do: &Select.select/1

  def imports,
    do: [
      {WatchClubWeb.Components.UI.Select,
       [
         select_group: 1,
         select_item: 1,
         select_label: 1,
         select_separator: 1
       ]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-80 items-start justify-center p-12 text-text">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  @genre_groups [
    {"Favorites",
     [
       {"noir", "Noir"},
       {"sci-fi", "Science fiction"},
       {"thriller", "Thriller"},
       {"drama", "Drama"},
       {"documentary", "Documentary"}
     ]},
    {"Weekend picks",
     [
       {"comedy", "Comedy"},
       {"adventure", "Adventure"},
       {"animation", "Animation"},
       {"fantasy", "Fantasy"},
       {"romance", "Romance"}
     ]},
    {"Deep cuts",
     [
       {"arthouse", "Arthouse"},
       {"classic", "Classic cinema"},
       {"foreign", "Foreign language"},
       {"silent", "Silent film"},
       {"experimental", "Experimental"}
     ]}
  ]

  defp scrollable_slots do
    Enum.flat_map(@genre_groups, fn {label, items} ->
      [
        "<.select_group>",
        ~s(<.select_label>#{label}</.select_label>)
      ] ++
        Enum.map(items, fn {value, text} ->
          ~s(<.select_item value="#{value}">#{text}</.select_item>)
        end) ++
        ["</.select_group>"]
    end)
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default select using Watch Club surface, border, and focus tokens",
        attributes: %{id: "wc-select-default", name: "status", placeholder: "Pick a status"},
        slots: [
          ~s(<.select_item value="watchlist">Watchlist</.select_item>),
          ~s(<.select_item value="watching">Watching now</.select_item>),
          ~s(<.select_item value="finished">Finished</.select_item>)
        ]
      },
      %Variation{
        id: :selected_value,
        description: "A value can be preselected from server assigns or a form field",
        attributes: %{
          id: "wc-select-selected",
          name: "status",
          value: "watching",
          placeholder: "Pick a status"
        },
        slots: [
          ~s(<.select_item value="watchlist">Watchlist</.select_item>),
          ~s(<.select_item value="watching">Watching now</.select_item>),
          ~s(<.select_item value="finished">Finished</.select_item>)
        ]
      },
      %Variation{
        id: :groups,
        description: "Grouped items with labels and a separator",
        attributes: %{id: "wc-select-groups", name: "genre", placeholder: "Pick a genre"},
        slots: [
          """
          <.select_group>
            <.select_label>Favorites</.select_label>
            <.select_item value="noir">Noir</.select_item>
            <.select_item value="sci-fi">Science fiction</.select_item>
            <.select_item value="thriller">Thriller</.select_item>
          </.select_group>
          """,
          ~s(<.select_separator />),
          """
          <.select_group>
            <.select_label>Weekend picks</.select_label>
            <.select_item value="comedy">Comedy</.select_item>
            <.select_item value="adventure">Adventure</.select_item>
            <.select_item value="animation" disabled>Animation (coming soon)</.select_item>
          </.select_group>
          """
        ]
      },
      %Variation{
        id: :scrollable,
        description: "Long grouped list — the overlay clamps to the available viewport height",
        attributes: %{
          id: "wc-select-scrollable",
          name: "genre",
          placeholder: "Pick a genre"
        },
        slots: scrollable_slots()
      },
      %Variation{
        id: :with_disabled_item,
        description: "Individual options can be disabled",
        attributes: %{id: "wc-select-disabled-item", name: "role", placeholder: "Pick a role"},
        slots: [
          ~s(<.select_item value="member">Member</.select_item>),
          ~s(<.select_item value="moderator">Moderator</.select_item>),
          ~s|<.select_item value="owner" disabled>Owner (already assigned)</.select_item>|
        ]
      },
      %Variation{
        id: :disabled,
        description: "Whole select disabled",
        attributes: %{
          id: "wc-select-disabled",
          name: "playlist",
          disabled: true,
          placeholder: "No playlists available"
        },
        slots: [
          ~s(<.select_item value="cinema">Cinema playlist</.select_item>),
          ~s(<.select_item value="books">Book playlist</.select_item>),
          ~s(<.select_item value="series">Series playlist</.select_item>)
        ]
      },
      %Variation{
        id: :invalid,
        description: "Validation state mirrors field errors through `aria-invalid`",
        attributes: %{
          id: "wc-select-invalid",
          name: "genre",
          placeholder: "Pick a genre",
          errors: ["Pick a genre"]
        },
        slots: [
          ~s(<.select_item value="noir">Noir</.select_item>),
          ~s(<.select_item value="sci-fi">Science fiction</.select_item>),
          ~s(<.select_item value="thriller">Thriller</.select_item>)
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes follow the shared control scale",
        template: """
        <div class="flex min-h-56 items-start justify-around gap-6 p-12 text-text">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for size <- ~w(sm md lg)a do
            size_string = Atom.to_string(size)

            %Variation{
              id: size,
              attributes: %{
                id: "wc-select-size-#{size_string}",
                name: "size",
                size: size_string,
                placeholder: "Size #{size_string}"
              },
              slots: [
                ~s(<.select_item value="movie">Movie</.select_item>),
                ~s(<.select_item value="book">Book</.select_item>),
                ~s(<.select_item value="show">TV show</.select_item>)
              ]
            }
          end
      }
    ]
  end
end
