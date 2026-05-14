defmodule WatchClubWeb.UI.Table do
  @moduledoc """
  Token-driven Watch Club table primitive.

  Table elements (`table`, `thead`, `tbody`, `tr`, `th`, `td`, `caption`)
  must keep their literal HTML nesting, so each is exposed as a composable
  component.
  """

  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table(assigns) do
    ~H"""
    <div
      data-slot="table-container"
      class="relative w-full overflow-x-auto rounded-control border border-border bg-surface shadow-card"
    >
      <table
        data-slot="table"
        class={["w-full caption-bottom text-sm text-text", @class]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </table>
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
      class={["border-b border-border-subtle bg-surface-raised/60 [&_tr]:border-b-0", @class]}
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
        "border-t border-border-subtle bg-surface-raised/60 font-medium [&>tr]:last:border-b-0",
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
        "border-b border-border-subtle transition-colors hover:bg-surface-hover has-aria-expanded:bg-surface-hover data-[state=selected]:bg-surface-selected",
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
        "h-control-md px-group text-center align-middle text-xs font-semibold whitespace-nowrap text-text-muted uppercase tracking-wide [&:has([role=checkbox])]:pr-0",
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
        "p-group text-center align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0",
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
