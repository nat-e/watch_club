defmodule WatchClub.Credo.UseOpentelemetryOban do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Jobs inserted with `Oban.insert/2`, `Oban.insert!/2` or `Oban.insert_all/2`
      lose the trace that inserted them. Use the `OpentelemetryOban` functions
      of the same name instead.
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)
    result = Credo.Code.prewalk(source_file, &walk/2, ctx)
    result.issues
  end

  defp walk({{:., _, [{:__aliases__, meta, [:Oban]}, function]}, _, _} = ast, ctx)
       when function in [:insert, :insert!, :insert_all] do
    issue =
      format_issue(ctx,
        message: "Use `OpentelemetryOban.#{function}` so jobs keep their trace.",
        trigger: "Oban.#{function}",
        line_no: meta[:line],
        column: meta[:column]
      )

    {ast, put_issue(ctx, issue)}
  end

  defp walk(ast, ctx), do: {ast, ctx}
end
