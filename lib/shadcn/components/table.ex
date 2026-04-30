defmodule Shadcn.Components.Table do
  @moduledoc """
  Tabular data, with header / body / footer / caption helpers.

      <.table>
        <.table_caption>Recent invoices</.table_caption>
        <.table_header>
          <.table_row>
            <.table_head>Invoice</.table_head>
            <.table_head>Status</.table_head>
            <.table_head class="text-right">Amount</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :for={inv <- @invoices}>
            <.table_cell>{inv.id}</.table_cell>
            <.table_cell>{inv.status}</.table_cell>
            <.table_cell class="text-right">${inv.amount}</.table_cell>
          </.table_row>
        </.table_body>
      </.table>

  Unlike most components in this library, the table elements (`thead`,
  `tbody`, `tr`, `th`, `td`, `caption`) cannot be remodeled as slots —
  HTML requires the literal element nesting — so each is its own
  component, and authors compose them directly.

  Ported from Shadcn on 2026-04-28
  Commit: 68a69d81f7de95a9fa2e83c16486771e37252ff3
  Source: https://github.com/shadcn-ui/ui/blob/68a69d81f7de95a9fa2e83c16486771e37252ff3/apps/v4/styles/radix-vega/ui/table.tsx
  Doc: https://ui.shadcn.com/docs/components/radix/table
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table(assigns) do
    ~H"""
    <div data-slot="table-container">
      <table data-slot="table" class={@class} {@rest}>
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
    <thead data-slot="table-header" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </thead>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_body(assigns) do
    ~H"""
    <tbody data-slot="table-body" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </tbody>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_footer(assigns) do
    ~H"""
    <tfoot data-slot="table-footer" class={@class} {@rest}>
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
      class={@class}
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
    <th data-slot="table-head" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </th>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(colspan rowspan)
  slot :inner_block, required: true

  def table_cell(assigns) do
    ~H"""
    <td data-slot="table-cell" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </td>
    """
  end

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def table_caption(assigns) do
    ~H"""
    <caption data-slot="table-caption" class={@class} {@rest}>
      {render_slot(@inner_block)}
    </caption>
    """
  end
end
