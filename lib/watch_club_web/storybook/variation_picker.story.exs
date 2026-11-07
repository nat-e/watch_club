defmodule WatchClubWeb.Storybook.VariationPicker do
  use PhoenixStorybook.Story, :component

  alias WatchClubWeb.Components.Prototypes.VariationPicker
  alias WatchClubWeb.Helpers.Url

  def function, do: &VariationPicker.variation_picker/1

  def variations do
    for {id, layout} <- [{:default, nil}, {:cards, "cards"}, {:unknown_value, "unknown"}] do
      %Variation{
        id: id,
        description:
          "Switching Layout keeps Density and every other URL parameter. Unknown choices fall back to the first option.",
        attributes: %{
          id: "layout-#{id}",
          label: "Layout",
          param: "layout",
          current_url: %Url{
            scheme: "http",
            authority: "localhost",
            path: "/dev/prototypes/example",
            query:
              Map.merge(
                %{"density" => "compact"},
                if(layout, do: %{"layout" => layout}, else: %{})
              )
          }
        },
        slots: [
          ~s(<:option value="rows" description="One item per row.">Rows</:option>),
          ~s(<:option value="cards" description="A visual overview of the choices.">Cards</:option>),
          ~s(<:option value="compact" description="More choices in less space.">Compact</:option>)
        ]
      }
    end
  end
end
