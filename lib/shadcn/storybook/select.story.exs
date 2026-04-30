defmodule Shadcn.Storybook.Select do
  use PhoenixStorybook.Story, :component

  alias Shadcn.Components.Select

  def function, do: &Select.select/1

  def imports,
    do: [
      {Shadcn.Components.Select,
       [
         select_group: 1,
         select_item: 1,
         select_label: 1,
         select_separator: 1
       ]}
    ]

  defp container_template(content) do
    """
    <div class="flex min-h-[320px] items-start justify-center p-12">
      #{content}
    </div>
    """
  end

  def template, do: container_template("<.psb-variation/>")

  @timezone_groups [
    {"North America",
     [
       {"est", "Eastern Standard Time (EST)"},
       {"cst", "Central Standard Time (CST)"},
       {"mst", "Mountain Standard Time (MST)"},
       {"pst", "Pacific Standard Time (PST)"},
       {"akst", "Alaska Standard Time (AKST)"},
       {"hst", "Hawaii Standard Time (HST)"}
     ]},
    {"Europe & Africa",
     [
       {"gmt", "Greenwich Mean Time (GMT)"},
       {"cet", "Central European Time (CET)"},
       {"eet", "Eastern European Time (EET)"},
       {"west", "Western European Summer Time (WEST)"},
       {"cat", "Central Africa Time (CAT)"},
       {"eat", "East Africa Time (EAT)"}
     ]},
    {"Asia",
     [
       {"msk", "Moscow Time (MSK)"},
       {"ist", "India Standard Time (IST)"},
       {"cst_china", "China Standard Time (CST)"},
       {"jst", "Japan Standard Time (JST)"},
       {"kst", "Korea Standard Time (KST)"},
       {"ist_indo", "Indonesia Central Standard Time (WITA)"}
     ]},
    {"Australia & Pacific",
     [
       {"awst", "Australian Western Standard Time (AWST)"},
       {"acst", "Australian Central Standard Time (ACST)"},
       {"aest", "Australian Eastern Standard Time (AEST)"},
       {"nzst", "New Zealand Standard Time (NZST)"},
       {"fjt", "Fiji Time (FJT)"}
     ]},
    {"South America",
     [
       {"art", "Argentina Time (ART)"},
       {"bot", "Bolivia Time (BOT)"},
       {"brt", "Brasilia Time (BRT)"},
       {"clt", "Chile Standard Time (CLT)"}
     ]}
  ]

  defp scrollable_slots do
    Enum.flat_map(@timezone_groups, fn {label, items} ->
      [
        "<.select_group>",
        ~s(<.select_label>#{label}</.select_label>)
      ] ++
        Enum.map(items, fn {v, t} ->
          ~s(<.select_item value="#{v}">#{t}</.select_item>)
        end) ++
        ["</.select_group>"]
    end)
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Basic select — pick a theme",
        attributes: %{id: "select-default", name: "theme", placeholder: "Theme"},
        slots: [
          ~s(<.select_item value="light">Light</.select_item>),
          ~s(<.select_item value="dark">Dark</.select_item>),
          ~s(<.select_item value="system">System</.select_item>)
        ]
      },
      %Variation{
        id: :groups,
        description: "Grouped items with labels and a separator",
        attributes: %{id: "select-groups", name: "food", placeholder: "Select a food"},
        slots: [
          """
          <.select_group>
            <.select_label>Fruits</.select_label>
            <.select_item value="apple">Apple</.select_item>
            <.select_item value="banana">Banana</.select_item>
            <.select_item value="blueberry">Blueberry</.select_item>
            <.select_item value="grapes">Grapes</.select_item>
            <.select_item value="pineapple">Pineapple</.select_item>
          </.select_group>
          """,
          ~s(<.select_separator />),
          """
          <.select_group>
            <.select_label>Vegetables</.select_label>
            <.select_item value="aubergine">Aubergine</.select_item>
            <.select_item value="broccoli">Broccoli</.select_item>
            <.select_item value="carrot" disabled>Carrot</.select_item>
            <.select_item value="courgette">Courgette</.select_item>
            <.select_item value="leek">Leek</.select_item>
          </.select_group>
          """
        ]
      },
      %Variation{
        id: :scrollable,
        description: "Long list with grouped sections — viewport scrolls",
        attributes: %{
          id: "select-scrollable",
          name: "timezone",
          placeholder: "Select a timezone"
        },
        slots: scrollable_slots()
      },
      %Variation{
        id: :with_disabled_item,
        description: "An individual item can be disabled",
        attributes: %{id: "select-disopt", name: "plan", placeholder: "Select a plan"},
        slots: [
          ~s(<.select_item value="basic">Basic</.select_item>),
          ~s(<.select_item value="pro">Pro</.select_item>),
          ~s|<.select_item value="ent" disabled>Enterprise (sold out)</.select_item>|
        ]
      },
      %Variation{
        id: :disabled,
        description: "Whole select disabled",
        attributes: %{
          id: "select-disabled",
          name: "fruit",
          disabled: true,
          placeholder: "Select a fruit"
        },
        slots: [
          ~s(<.select_item value="apple">Apple</.select_item>),
          ~s(<.select_item value="banana">Banana</.select_item>),
          ~s(<.select_item value="blueberry">Blueberry</.select_item>)
        ]
      },
      %Variation{
        id: :invalid,
        description: "Error state — `errors` set, trigger gets `aria-invalid`",
        attributes: %{
          id: "select-invalid",
          name: "fruit",
          placeholder: "Select a fruit",
          errors: ["Please select a fruit."]
        },
        slots: [
          ~s(<.select_item value="apple">Apple</.select_item>),
          ~s(<.select_item value="banana">Banana</.select_item>),
          ~s(<.select_item value="blueberry">Blueberry</.select_item>)
        ]
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes (sm, default)",
        template: """
        <div class="flex min-h-[200px] items-start justify-around gap-6 p-12">
          <.psb-variation-group/>
        </div>
        """,
        variations:
          for s <- ~w(sm default) do
            %Variation{
              id: String.to_atom(s),
              attributes: %{
                id: "select-size-#{s}",
                name: "x",
                size: s,
                placeholder: "Size #{s}"
              },
              slots: [
                ~s(<.select_item value="a">Apple</.select_item>),
                ~s(<.select_item value="b">Banana</.select_item>),
                ~s(<.select_item value="c">Blueberry</.select_item>)
              ]
            }
          end
      }
    ]
  end
end
