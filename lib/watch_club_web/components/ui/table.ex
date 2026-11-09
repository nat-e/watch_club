defmodule WatchClubWeb.Components.UI.Table do
  @moduledoc """
  Token-driven Watch Club table primitive.

  Table elements (`table`, `thead`, `tbody`, `tr`, `th`, `td`, `caption`)
  must keep their literal HTML nesting, so each is exposed as a composable
  component. Text starts at the left; pass `text-right!` for numbers.
  """

  use Phoenix.Component

  attr :class, :any, default: nil

  attr :density, :string,
    values: ~w(default compact),
    default: "default",
    doc: "`compact` halves the cells' vertical padding, for long lists"

  attr :rest, :global
  slot :inner_block, required: true
  slot :footer, doc: "below the rows, inside the table's border, such as its pages"

  def table(assigns) do
    ~H"""
    <div
      data-slot="table-container"
      class={[
        "relative w-full overflow-hidden rounded-card border border-border bg-surface shadow-card",
        @class
      ]}
    >
      <div class="overflow-x-auto">
        <table
          data-slot="table"
          data-density={@density}
          class="w-full caption-bottom text-sm text-text"
          {@rest}
        >
          {render_slot(@inner_block)}
        </table>
      </div>
      <div
        :if={@footer != []}
        data-slot="table-container-footer"
        class="border-t border-border-subtle bg-surface-raised px-group py-related"
      >
        {render_slot(@footer)}
      </div>
    </div>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_header(assigns) do
    ~H"""
    <thead
      data-slot="table-header"
      class={["border-b border-border-subtle bg-surface-raised [&_tr]:border-b-0", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </thead>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_body(assigns) do
    ~H"""
    <tbody data-slot="table-body" class={["[&_tr:last-child]:border-0", @class]} {@rest}>
      {render_slot(@inner_block)}
    </tbody>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_footer(assigns) do
    ~H"""
    <tfoot
      data-slot="table-footer"
      class={[
        "border-t border-border-subtle bg-surface-raised font-semibold [&>tr]:last:border-b-0",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </tfoot>
    """
  end

  attr :class, :any, default: nil
  attr :selected, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  def table_row(assigns) do
    ~H"""
    <tr
      data-slot="table-row"
      data-state={if @selected, do: "selected"}
      class={[
        "border-b border-border-subtle transition-colors",
        @selected && "bg-surface-selected",
        !@selected && "hover:bg-surface-hover has-aria-expanded:bg-surface-hover",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </tr>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(scope colspan rowspan abbr)
  slot :inner_block, required: true

  def table_head(assigns) do
    ~H"""
    <th
      data-slot="table-head"
      class={[
        "h-control-md px-group text-left align-middle text-xs font-semibold whitespace-nowrap text-text-muted uppercase tracking-wider has-[[role=checkbox]]:pr-0",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </th>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(colspan rowspan)
  slot :inner_block, required: true

  def table_cell(assigns) do
    ~H"""
    <td
      data-slot="table-cell"
      class={[
        "p-group text-left align-middle whitespace-nowrap has-[[role=checkbox]]:pr-0 [[data-density=compact]_&]:py-related",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </td>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_caption(assigns) do
    ~H"""
    <caption data-slot="table-caption" class={["mt-group text-sm text-text-muted", @class]} {@rest}>
      {render_slot(@inner_block)}
    </caption>
    """
  end
end
