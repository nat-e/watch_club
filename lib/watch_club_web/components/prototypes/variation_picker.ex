defmodule WatchClubWeb.Components.Prototypes.VariationPicker do
  @moduledoc "A URL-based picker for one experiment axis; other axes and page parameters are kept."
  use WatchClubWeb, :component

  alias WatchClubWeb.Helpers.Url

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :param, :string, required: true
  attr :current_url, Url, required: true

  slot :option, required: true do
    attr :value, :string, required: true
    attr :description, :string
  end

  def variation_picker(assigns) do
    values = Enum.map(assigns.option, & &1.value)

    assigns =
      assign(
        assigns,
        :selected,
        Url.parse_url_param(assigns.current_url.query[assigns.param], values, hd(values))
      )

    ~H"""
    <section id={@id} aria-labelledby={"#{@id}-label"} class="flex min-w-0 flex-col gap-related">
      <h2 id={"#{@id}-label"} class="text-sm font-semibold">{@label}</h2>
      <div class="max-w-full overflow-x-auto pb-tight">
        <.segmented_control aria-labelledby={"#{@id}-label"} class="w-max! min-w-0">
          <:item
            :for={option <- @option}
            id={"#{@id}-#{option.value}"}
            selected={@selected == option.value}
            patch={@current_url |> Url.add_param(@param, option.value) |> Url.to_url()}
            class="grow-0! basis-auto! whitespace-nowrap"
          >
            {render_slot(option)}
          </:item>
        </.segmented_control>
      </div>
      <p
        :for={option <- @option}
        :if={option.value == @selected && option[:description]}
        class="max-w-readable text-sm text-text-muted"
      >
        {option.description}
      </p>
    </section>
    """
  end
end
