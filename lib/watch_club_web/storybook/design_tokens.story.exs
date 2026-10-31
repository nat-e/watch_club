defmodule WatchClubWeb.Storybook.DesignTokens do
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  def doc do
    "A simplified semantic token system for Watch Club's Velvet Club design direction."
  end

  def navigation do
    [
      {:overview, "Overview", {:fa, "palette"}},
      {:tokens, "Tokens", {:fa, "code"}},
      {:applied, "Applied examples", {:fa, "rectangle-ad"}},
      {:feedback, "Feedback", {:fa, "circle-question"}}
    ]
  end

  def render(%{tab: :tokens} = assigns) do
    assigns = Map.put(assigns, :categories, token_categories())

    ~H"""
    <.page_shell>
      <.intro eyebrow="Simplified token catalog" title="Small semantic v0, designed to grow slowly">
        This version keeps only the meanings we expect to use immediately. If a future component needs a
        repeated meaning that is not represented here, we add one token then — not now.
      </.intro>

      <div class="grid gap-6">
        <.token_category :for={category <- @categories} category={category} />
      </div>
    </.page_shell>
    """
  end

  def render(%{tab: :applied} = assigns) do
    assigns = Map.put(assigns, :recommendations, recommendations())

    ~H"""
    <.page_shell>
      <.intro eyebrow="Applied examples" title="Real screens using only the simplified tokens">
        These screens intentionally avoid component-specific tokens. If something feels awkward or unclear,
        that is useful evidence for the next token we may need.
      </.intro>

      <div class="grid gap-8">
        <.settings_example />
        <.login_example />
        <.recommendations_example recommendations={@recommendations} />
      </div>
    </.page_shell>
    """
  end

  def render(%{tab: :feedback} = assigns) do
    ~H"""
    <.page_shell>
      <.intro eyebrow="Feedback" title="Judge simplicity and missing meanings">
        The goal is not perfect coverage. The goal is a token set small enough to remember and strong enough
        to rebuild the first Watch Club UI components.
      </.intro>

      <div class="grid gap-4 md:grid-cols-2">
        <.feedback_card number="1" title="Missing meanings">
          Which repeated UI decisions are not covered by this smaller set? Examples: table row states,
          watched indicators, poster overlays, validation, navigation, overlays.
        </.feedback_card>
        <.feedback_card number="2" title="Too many tokens">
          Which tokens still feel unnecessary before we build the first component pass?
        </.feedback_card>
        <.feedback_card number="3" title="Unclear names">
          Which names would you hesitate over when writing a component? Those names should change.
        </.feedback_card>
        <.feedback_card number="4" title="Visual fit">
          Which examples feel too bright, too flat, too purple, or not cozy enough?
        </.feedback_card>
      </div>
    </.page_shell>
    """
  end

  def render(assigns) do
    assigns = Map.put(assigns, :categories, token_categories())

    ~H"""
    <.page_shell>
      <.intro eyebrow="Selected direction" title="Velvet Club: simplified semantic tokens">
        Dark aubergine surfaces, pink primary actions, lavender supporting accents, comfortable
        rounded shapes, and readable contrast — with a smaller token set.
      </.intro>

      <div class="grid gap-6 xl:grid-cols-[1fr_0.8fr]">
        <section
          class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
          style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
        >
          <p
            class="text-xs font-semibold uppercase tracking-[0.24em]"
            style="color: var(--wc-color-accent)"
          >
            Operating rule
          </p>
          <h2 class="mt-3 text-3xl font-semibold tracking-tight" style="color: var(--wc-color-text)">
            Add tokens only when repetition proves a missing meaning.
          </h2>
          <p class="mt-4 max-w-2xl leading-7" style="color: var(--wc-color-text-muted)">
            Start with generic semantic roles. Keep one neutral text scale for all neutral surfaces.
            Add paired foreground tokens only for strong fills like primary, accent, and danger.
          </p>

          <div class="mt-6 grid gap-3 md:grid-cols-3">
            <.principle title="Small" text="~40 tokens instead of a mature enterprise-scale catalog." />
            <.principle title="Semantic" text="Names describe purpose, not purple values." />
            <.principle title="Expandable" text="Missing repeated meanings become new tokens later." />
          </div>
        </section>

        <section
          class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
          style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
        >
          <p
            class="text-xs font-semibold uppercase tracking-[0.24em]"
            style="color: var(--wc-color-accent)"
          >
            Token count
          </p>
          <div class="mt-4 grid gap-3">
            <div
              :for={category <- @categories}
              class="flex items-center justify-between rounded-[var(--wc-radius-control)] px-3 py-2"
              style="background: var(--wc-color-surface-inset)"
            >
              <span style="color: var(--wc-color-text-muted)">{category.title}</span>
              <strong style="color: var(--wc-color-text)">{length(category.tokens)}</strong>
            </div>
          </div>
        </section>
      </div>
    </.page_shell>
    """
  end

  slot :inner_block, required: true

  defp page_shell(assigns) do
    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen rounded-lg bg-canvas p-8 text-text">
      <div class="mx-auto flex max-w-7xl flex-col gap-8">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp intro(assigns) do
    ~H"""
    <section
      class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
    >
      <p
        class="text-xs font-semibold uppercase tracking-[0.28em]"
        style="color: var(--wc-color-accent)"
      >
        {@eyebrow}
      </p>
      <h1
        class="mt-3 max-w-4xl text-3xl font-semibold tracking-tight md:text-5xl"
        style="color: var(--wc-color-text)"
      >
        {@title}
      </h1>
      <p class="mt-4 max-w-3xl text-base leading-7" style="color: var(--wc-color-text-muted)">
        {render_slot(@inner_block)}
      </p>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :text, :string, required: true

  defp principle(assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="background: var(--wc-color-surface-raised); border-color: var(--wc-color-border-subtle)"
    >
      <h3 class="font-semibold" style="color: var(--wc-color-text)">{@title}</h3>
      <p class="mt-1 text-sm leading-6" style="color: var(--wc-color-text-muted)">{@text}</p>
    </div>
    """
  end

  attr :category, :map, required: true

  defp token_category(assigns) do
    ~H"""
    <section
      class="rounded-[var(--wc-radius-card)] border p-5 shadow-[var(--wc-shadow-card)]"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
    >
      <div
        class="flex flex-col gap-3 border-b pb-5 md:flex-row md:items-start md:justify-between"
        style="border-color: var(--wc-color-border-subtle)"
      >
        <div>
          <p
            class="text-xs font-semibold uppercase tracking-[0.24em]"
            style="color: var(--wc-color-accent)"
          >
            {@category.group}
          </p>
          <h2 class="mt-2 text-2xl font-semibold tracking-tight" style="color: var(--wc-color-text)">
            {@category.title}
          </h2>
          <p class="mt-2 max-w-3xl text-sm leading-6" style="color: var(--wc-color-text-muted)">
            {@category.description}
          </p>
        </div>
        <span
          class="rounded-[var(--wc-radius-full)] border px-3 py-1 text-xs font-medium"
          style="border-color: var(--wc-color-border); color: var(--wc-color-text-muted); background: var(--wc-color-surface-raised)"
        >
          {length(@category.tokens)} tokens
        </span>
      </div>

      <div class="mt-5 grid gap-4">
        <.token_card :for={token <- @category.tokens} token={token} />
      </div>
    </section>
    """
  end

  attr :token, :map, required: true

  defp token_card(assigns) do
    ~H"""
    <article
      class="grid gap-4 rounded-[var(--wc-radius-control)] border p-4 lg:grid-cols-[minmax(0,1fr)_18rem]"
      style="background: var(--wc-color-surface-raised); border-color: var(--wc-color-border-subtle)"
    >
      <div>
        <div class="flex flex-wrap items-center gap-2">
          <code
            class="rounded-lg border px-2 py-1 text-xs font-semibold"
            style="border-color: var(--wc-color-border); background: var(--wc-color-surface-inset); color: var(--wc-color-primary)"
          >
            {@token.name}
          </code>
          <span
            class="rounded-[var(--wc-radius-full)] px-2 py-1 text-[0.68rem] font-semibold uppercase tracking-[0.16em]"
            style="background: var(--wc-color-surface-inset); color: var(--wc-color-text-muted)"
          >
            {@token.kind}
          </span>
        </div>

        <p class="mt-3 text-sm leading-6" style="color: var(--wc-color-text)">
          {@token.meaning}
        </p>

        <p
          class="mt-4 text-xs font-semibold uppercase tracking-[0.18em]"
          style="color: var(--wc-color-text-subtle)"
        >
          Concrete use cases
        </p>
        <ul class="mt-2 grid gap-2 text-sm" style="color: var(--wc-color-text-muted)">
          <li :for={use_case <- @token.use_cases} class="flex gap-2">
            <span
              class="mt-2 size-1.5 shrink-0 rounded-full"
              style="background: var(--wc-color-accent)"
            ></span>
            <span>{use_case}</span>
          </li>
        </ul>
      </div>

      <.token_preview token={@token} />
    </article>
    """
  end

  attr :token, :map, required: true

  defp token_preview(%{token: %{kind: :text}} = assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface)"
    >
      <p class="text-lg font-semibold" style={"color: var(#{token_var(@token)})"}>
        Readable text sample
      </p>
      <p class="mt-2 text-sm" style="color: var(--wc-color-text-muted)">
        Labels, copy, metadata, or disabled states.
      </p>
    </div>
    """
  end

  defp token_preview(%{token: %{kind: :border}} = assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface)"
    >
      <div
        class="grid h-24 place-items-center rounded-[var(--wc-radius-control)] border-2 border-dashed text-sm"
        style={"border-color: var(#{token_var(@token)}); color: var(--wc-color-text-muted)"}
      >
        Boundary sample
      </div>
    </div>
    """
  end

  defp token_preview(%{token: %{kind: :fill}} = assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface)"
    >
      <button
        id={"token-preview-fill-#{String.replace(@token.name, ".", "-")}"}
        class="w-full rounded-[var(--wc-radius-control)] px-4 py-3 text-sm font-semibold"
        style={"background: var(#{token_var(@token)}); color: #{Map.get(@token, :on, "var(--wc-color-on-primary)")}"}
      >
        Filled element
      </button>
    </div>
    """
  end

  defp token_preview(%{token: %{kind: :radius}} = assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface)"
    >
      <div
        class="h-24 border"
        style={"border-radius: var(#{token_var(@token)}); border-color: var(--wc-color-border-strong); background: var(--wc-color-surface-inset)"}
      >
      </div>
    </div>
    """
  end

  defp token_preview(%{token: %{kind: :shadow}} = assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-6"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface-inset)"
    >
      <div
        class="rounded-[var(--wc-radius-control)] p-5 text-center text-sm"
        style={"box-shadow: var(#{token_var(@token)}); background: var(--wc-color-surface); color: var(--wc-color-text-muted)"}
      >
        elevation
      </div>
    </div>
    """
  end

  defp token_preview(%{token: %{kind: :size}} = assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface)"
    >
      <div
        class="grid place-items-center rounded-[var(--wc-radius-control)] border text-xs"
        style={"width: var(#{token_var(@token)}); height: var(#{token_var(@token)}); min-width: 2rem; min-height: 2rem; border-color: var(--wc-color-border-strong); color: var(--wc-color-text-muted)"}
      >
        size
      </div>
    </div>
    """
  end

  defp token_preview(assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] border p-4"
      style="border-color: var(--wc-color-border-subtle); background: var(--wc-color-surface)"
    >
      <div
        class="grid h-24 place-items-center rounded-[var(--wc-radius-control)] text-center text-sm font-semibold"
        style={"background: var(#{token_var(@token)}); color: #{Map.get(@token, :preview_text, "var(--wc-color-text)")}"}
      >
        {@token.preview_label || @token.name}
      </div>
    </div>
    """
  end

  defp settings_example(assigns) do
    ~H"""
    <section
      class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
    >
      <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p
            class="text-xs font-semibold uppercase tracking-[0.22em]"
            style="color: var(--wc-color-accent)"
          >
            Settings section
          </p>
          <h2 class="mt-2 text-3xl font-semibold tracking-tight" style="color: var(--wc-color-text)">
            Club settings
          </h2>
          <p class="mt-2 max-w-3xl" style="color: var(--wc-color-text-muted)">
            Navigation, grouped fields, toggles, helper copy, save state, and warning callout.
          </p>
        </div>
        <div
          class="rounded-[var(--wc-radius-full)] border px-3 py-1 text-xs font-medium"
          style="border-color: var(--wc-color-success-border); background: var(--wc-color-success-bg); color: var(--wc-color-success)"
        >
          Saved 2 min ago
        </div>
      </div>

      <div class="mt-6 grid gap-5 xl:grid-cols-[17rem_minmax(0,1fr)]">
        <aside
          class="rounded-[var(--wc-radius-card)] border p-3"
          style="background: var(--wc-color-surface-inset); border-color: var(--wc-color-border-subtle)"
        >
          <nav class="grid gap-1 text-sm">
            <.nav_item label="General" active />
            <.nav_item label="Members" />
            <.nav_item label="Library" />
            <.nav_item label="Notifications" />
            <.nav_item label="Billing" />
          </nav>
        </aside>

        <div class="grid gap-5">
          <div
            class="rounded-[var(--wc-radius-card)] border p-5"
            style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
          >
            <h3 class="text-lg font-semibold" style="color: var(--wc-color-text)">
              Kflix preferences
            </h3>
            <p class="mt-1 text-sm" style="color: var(--wc-color-text-muted)">
              Decide how recommendations and member activity appear for this club.
            </p>

            <div class="mt-6 grid gap-5 lg:grid-cols-2">
              <.field
                id="design-token-club-name-input"
                label="Club name"
                value="Kflix"
                helper="Visible to invited members."
                focused
              />
              <.select_field
                label="Default visibility"
                value="Members only"
                helper="Controls who can browse the library."
              />
            </div>
          </div>

          <div
            class="divide-y overflow-hidden rounded-[var(--wc-radius-card)] border"
            style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle); --tw-divide-color: var(--wc-color-border-subtle)"
          >
            <.setting_toggle
              title="Include watched media"
              description="Keep watched titles visible with a clear watched indicator."
              checked
            />
            <.setting_toggle
              title="Weekly digest"
              description="Send a summary of new recommendations every Friday."
              checked
            />
            <.setting_toggle
              title="Anonymous voting"
              description="Hide member names until everyone has voted."
            />
          </div>

          <div
            class="rounded-[var(--wc-radius-card)] border p-5"
            style="background: var(--wc-color-warning-bg); border-color: var(--wc-color-warning-border)"
          >
            <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
              <div>
                <h3 class="font-semibold" style="color: var(--wc-color-warning)">
                  Archive inactive recommendations
                </h3>
                <p class="mt-1 text-sm" style="color: var(--wc-color-text-muted)">
                  34 old recommendations have not been discussed in over 6 months.
                </p>
              </div>
              <button
                id="design-token-warning-review-archive-button"
                class="rounded-[var(--wc-radius-control)] border px-4 py-2 text-sm font-semibold"
                style="border-color: var(--wc-color-warning-border); color: var(--wc-color-warning); background: var(--wc-color-surface)"
              >
                Review archive
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <div
      class="rounded-[var(--wc-radius-control)] px-3 py-2 font-medium"
      style={nav_item_style(@active)}
    >
      {@label}
    </div>
    """
  end

  defp nav_item_style(true),
    do: "background: var(--wc-color-surface-selected); color: var(--wc-color-text)"

  defp nav_item_style(false), do: "color: var(--wc-color-text-muted)"

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :helper, :string, required: true
  attr :focused, :boolean, default: false

  defp field(assigns) do
    ~H"""
    <label for={@id} class="grid gap-2">
      <span class="text-sm font-medium" style="color: var(--wc-color-text)">{@label}</span>
      <input
        id={@id}
        value={@value}
        class="h-[var(--wc-size-control-md)] rounded-[var(--wc-radius-control)] border px-3 text-sm outline-none"
        style={field_style(@focused)}
      />
      <span class="text-xs" style="color: var(--wc-color-text-muted)">{@helper}</span>
    </label>
    """
  end

  defp field_style(true) do
    "background: var(--wc-color-surface-inset); border-color: var(--wc-color-border-focus); color: var(--wc-color-text); box-shadow: 0 0 0 2px color-mix(in oklab, var(--wc-color-border-focus), transparent 70%)"
  end

  defp field_style(false) do
    "background: var(--wc-color-surface-inset); border-color: var(--wc-color-border); color: var(--wc-color-text)"
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :helper, :string, required: true

  defp select_field(assigns) do
    ~H"""
    <label class="grid gap-2">
      <span class="text-sm font-medium" style="color: var(--wc-color-text)">{@label}</span>
      <div
        class="flex h-[var(--wc-size-control-md)] items-center justify-between rounded-[var(--wc-radius-control)] border px-3 text-sm"
        style="background: var(--wc-color-surface-inset); border-color: var(--wc-color-border); color: var(--wc-color-text)"
      >
        {@value}<span style="color: var(--wc-color-text-muted)">⌄</span>
      </div>
      <span class="text-xs" style="color: var(--wc-color-text-muted)">{@helper}</span>
    </label>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :checked, :boolean, default: false

  defp setting_toggle(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 p-5 md:flex-row md:items-center md:justify-between">
      <div>
        <h4 class="font-medium" style="color: var(--wc-color-text)">{@title}</h4>
        <p class="mt-1 max-w-2xl text-sm leading-6" style="color: var(--wc-color-text-muted)">
          {@description}
        </p>
      </div>
      <div class="flex items-center gap-3">
        <span class="text-xs" style="color: var(--wc-color-text-subtle)">
          {if @checked, do: "Enabled", else: "Disabled"}
        </span>
        <div
          class="flex h-7 w-12 items-center rounded-[var(--wc-radius-full)] p-1"
          style={toggle_track_style(@checked)}
        >
          <span
            class={["size-5 rounded-[var(--wc-radius-full)] transition", @checked && "translate-x-5"]}
            style="background: var(--wc-color-on-primary)"
          ></span>
        </div>
      </div>
    </div>
    """
  end

  defp toggle_track_style(true), do: "background: var(--wc-color-primary)"
  defp toggle_track_style(false), do: "background: var(--wc-color-surface-raised)"

  defp login_example(assigns) do
    ~H"""
    <section
      class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
    >
      <div>
        <p
          class="text-xs font-semibold uppercase tracking-[0.22em]"
          style="color: var(--wc-color-accent)"
        >
          Login form
        </p>
        <h2 class="mt-2 text-3xl font-semibold tracking-tight" style="color: var(--wc-color-text)">
          Sign in to Watch Club
        </h2>
        <p class="mt-2 max-w-3xl" style="color: var(--wc-color-text-muted)">
          Authentication card with brand panel, focused field, info message, and primary action.
        </p>
      </div>

      <div
        class="mx-auto mt-6 grid w-full max-w-5xl overflow-hidden rounded-[var(--wc-radius-card)] border shadow-[var(--wc-shadow-overlay)] lg:grid-cols-[1fr_28rem]"
        style="background: var(--wc-color-surface-overlay); border-color: var(--wc-color-border-subtle)"
      >
        <div
          class="relative hidden min-h-[34rem] overflow-hidden p-8 lg:block"
          style="background: radial-gradient(circle at 20% 15%, var(--wc-color-accent), transparent 24%), radial-gradient(circle at 80% 30%, var(--wc-color-primary), transparent 28%), linear-gradient(145deg, var(--wc-color-surface-raised), var(--wc-color-canvas))"
        >
          <div class="relative z-10 flex h-full flex-col justify-between">
            <div>
              <div
                class="grid size-12 place-items-center rounded-[var(--wc-radius-control)] text-xl font-bold"
                style="background: var(--wc-color-primary); color: var(--wc-color-on-primary)"
              >
                W
              </div>
              <h3
                class="mt-8 max-w-sm text-4xl font-semibold tracking-tight"
                style="color: var(--wc-color-text)"
              >
                Pick the next movie night without the group chat chaos.
              </h3>
              <p class="mt-4 max-w-sm text-sm leading-6" style="color: var(--wc-color-text-muted)">
                Collect recommendations, vote asynchronously, and keep a shared memory of what your club watched.
              </p>
            </div>
            <div
              class="rounded-[var(--wc-radius-card)] border p-4"
              style="background: rgb(255 255 255 / 8%); border-color: var(--wc-color-border-subtle)"
            >
              <p class="text-sm leading-6" style="color: var(--wc-color-text-muted)">
                “Friday picks are finally organized. No more scrolling through old messages.”
              </p>
              <p class="mt-3 text-sm font-semibold" style="color: var(--wc-color-text)">
                Camille · Kflix admin
              </p>
            </div>
          </div>
        </div>

        <div class="p-6 md:p-8">
          <h3 class="text-2xl font-semibold tracking-tight" style="color: var(--wc-color-text)">
            Welcome back
          </h3>
          <p class="mt-2 text-sm" style="color: var(--wc-color-text-muted)">
            Sign in to continue to your clubs.
          </p>
          <div class="mt-8 grid gap-5">
            <.field id="design-token-email-input" label="Email" value="nate@kflix.club" helper="" />
            <.field
              id="design-token-password-input"
              label="Password"
              value="••••••••••••"
              helper=""
              focused
            />
            <div
              class="rounded-[var(--wc-radius-card)] border p-3 text-sm"
              style="background: var(--wc-color-info-bg); border-color: var(--wc-color-info-border); color: var(--wc-color-info)"
            >
              New device sign-ins require email confirmation for club safety.
            </div>
            <button
              id="design-token-sign-in-button"
              class="h-[var(--wc-size-control-lg)] rounded-[var(--wc-radius-control)] text-sm font-semibold shadow-[var(--wc-shadow-glow)]"
              style="background: var(--wc-color-primary); color: var(--wc-color-on-primary)"
            >
              Sign in
            </button>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :recommendations, :list, required: true

  defp recommendations_example(assigns) do
    ~H"""
    <section
      class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
    >
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p
            class="text-xs font-semibold uppercase tracking-[0.22em]"
            style="color: var(--wc-color-accent)"
          >
            Recommendation cards page
          </p>
          <h2 class="mt-2 text-3xl font-semibold tracking-tight" style="color: var(--wc-color-text)">
            Recommended in Kflix
          </h2>
          <p class="mt-2 max-w-3xl" style="color: var(--wc-color-text-muted)">
            Dense media grid inspired by your screenshot: compact controls, poster art, watched state, and recommender metadata.
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <label
            class="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.12em]"
            style="color: var(--wc-color-text-muted)"
          >
            <span
              class="grid size-5 place-items-center rounded-md border text-[0.65rem]"
              style="background: var(--wc-color-primary); border-color: var(--wc-color-primary); color: var(--wc-color-on-primary)"
            >
              ✓
            </span>
            Include media I’ve watched
          </label>
          <button
            id="design-token-filter-button"
            class="h-[var(--wc-size-control-sm)] rounded-[var(--wc-radius-control)] border px-3 text-sm"
            style="background: var(--wc-color-surface-raised); border-color: var(--wc-color-border); color: var(--wc-color-text)"
          >
            All ⌄
          </button>
        </div>
      </div>

      <div
        class="mt-5 rounded-[var(--wc-radius-card)] border p-4"
        style="background: var(--wc-color-canvas); border-color: var(--wc-color-border-subtle)"
      >
        <div class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-5 2xl:grid-cols-8">
          <.recommendation_card :for={item <- @recommendations} item={item} />
        </div>
      </div>
    </section>
    """
  end

  attr :item, :map, required: true

  defp recommendation_card(assigns) do
    ~H"""
    <article
      class="group rounded-[var(--wc-radius-card)] border p-3 shadow-[var(--wc-shadow-card)] transition hover:-translate-y-0.5"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle); transition-duration: 120ms"
    >
      <div class="mb-3 flex items-start justify-between gap-2">
        <div class="min-w-0">
          <h4 class="truncate text-sm font-semibold" style="color: var(--wc-color-text)">
            {@item.title}
          </h4>
          <p class="mt-1 truncate text-xs" style="color: var(--wc-color-text-muted)">
            {@item.subtitle}
          </p>
        </div>
        <button
          id={"recommendation-card-actions-#{String.replace(@item.title, " ", "-")}"}
          class="grid size-8 shrink-0 place-items-center rounded-lg border text-lg leading-none"
          style="background: var(--wc-color-surface-inset); border-color: var(--wc-color-border-subtle); color: var(--wc-color-text-muted)"
        >
          ⋯
        </button>
      </div>

      <div
        class="relative aspect-[2/3] overflow-hidden rounded-[calc(var(--wc-radius-card)-0.5rem)] border"
        style="border-color: var(--wc-color-border-subtle)"
      >
        <div class="absolute inset-0" style={poster_style(@item)}></div>
        <div class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent p-3">
          <p class="text-lg font-bold leading-none tracking-tight text-white">{@item.poster_label}</p>
          <p class="mt-1 text-[0.65rem] uppercase tracking-[0.2em] text-white/70">{@item.kind}</p>
        </div>
        <span
          :if={@item.watched}
          class="absolute right-2 top-2 grid size-6 place-items-center rounded-full border text-xs font-bold"
          style="background: var(--wc-color-success-bg); border-color: var(--wc-color-success-border); color: var(--wc-color-success)"
        >
          ✓
        </span>
      </div>

      <div class="mt-3 flex items-center gap-2 text-xs" style="color: var(--wc-color-text-muted)">
        <span>◈</span>
        <span>Rec’d by <strong style="color: var(--wc-color-text)">{@item.by}</strong></span>
      </div>
    </article>
    """
  end

  attr :number, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp feedback_card(assigns) do
    ~H"""
    <section
      class="rounded-[var(--wc-radius-card)] border p-6 shadow-[var(--wc-shadow-card)]"
      style="background: var(--wc-color-surface); border-color: var(--wc-color-border-subtle)"
    >
      <div class="flex items-start gap-4">
        <div
          class="grid size-10 shrink-0 place-items-center rounded-[var(--wc-radius-control)] text-sm font-bold"
          style="background: var(--wc-color-primary); color: var(--wc-color-on-primary)"
        >
          {@number}
        </div>
        <div>
          <h3 class="font-semibold" style="color: var(--wc-color-text)">{@title}</h3>
          <p class="mt-2 text-sm leading-6" style="color: var(--wc-color-text-muted)">
            {render_slot(@inner_block)}
          </p>
        </div>
      </div>
    </section>
    """
  end

  defp token_categories do
    [
      %{
        group: "Color",
        title: "Surfaces",
        description: "The smallest useful set of backgrounds and container layers.",
        tokens: [
          background_token("color.canvas", "The app/page canvas.", [
            "root layout",
            "recommendation page background",
            "full-screen auth background"
          ]),
          background_token("color.surface", "Default card or panel surface.", [
            "settings panel",
            "login card",
            "recommendation card"
          ]),
          background_token(
            "color.surface-raised",
            "Interactive or visually lifted neutral surface.",
            ["hoverable item", "menu option", "secondary button"]
          ),
          background_token("color.surface-inset", "Recessed surface inside a parent surface.", [
            "inputs",
            "search boxes",
            "code blocks"
          ]),
          background_token("color.surface-overlay", "Floating overlay surface.", [
            "dialog",
            "popover",
            "dropdown menu"
          ]),
          background_token(
            "color.surface-hover",
            "Shared hover state for neutral interactive surfaces.",
            ["ghost button hover", "menu item hover", "table row hover"]
          ),
          background_token(
            "color.surface-active",
            "Shared pressed state for neutral interactive surfaces.",
            ["pressed ghost button", "active list row", "pressed menu item"]
          ),
          background_token("color.surface-selected", "Selected neutral surface.", [
            "active nav item",
            "selected card",
            "selected filter"
          ])
        ]
      },
      %{
        group: "Color",
        title: "Text",
        description: "One neutral text hierarchy that must work on all neutral dark surfaces.",
        tokens: [
          text_token("color.text", "Primary readable text.", [
            "headings",
            "body copy",
            "form labels"
          ]),
          text_token("color.text-muted", "Secondary readable text.", [
            "metadata",
            "helper text",
            "descriptions"
          ]),
          text_token("color.text-subtle", "Low-emphasis text.", [
            "timestamps",
            "placeholders",
            "quiet hints"
          ]),
          text_token("color.text-disabled", "Disabled text.", [
            "disabled labels",
            "unavailable actions",
            "locked settings"
          ])
        ]
      },
      %{
        group: "Color",
        title: "Borders and focus",
        description: "A compact set for structure, dividers, emphasis, and keyboard/input focus.",
        tokens: [
          border_token("color.border", "Default visible border.", ["cards", "inputs", "menus"]),
          border_token("color.border-subtle", "Low-emphasis structural border.", [
            "dividers",
            "table rows",
            "nested panels"
          ]),
          border_token("color.border-strong", "High-emphasis neutral border.", [
            "drop targets",
            "important panels",
            "selected boundaries"
          ]),
          border_token("color.border-focus", "Focus and focused input border.", [
            "keyboard focus",
            "focused fields",
            "combobox focus"
          ])
        ]
      },
      %{
        group: "Color",
        title: "Actions",
        description:
          "Strong fills with paired foreground colors where normal text tokens are not appropriate.",
        tokens: [
          fill_token(
            "color.primary",
            "Main Watch Club action fill.",
            ["primary button", "active checkbox", "primary selected action"],
            on: "var(--wc-color-on-primary)"
          ),
          fill_token(
            "color.primary-hover",
            "Hover state for primary actions.",
            ["primary button hover", "primary link-card hover", "main CTA hover"],
            on: "var(--wc-color-on-primary)"
          ),
          fill_token(
            "color.primary-active",
            "Pressed state for primary actions.",
            ["primary button active", "mouse-down primary action", "active drag target"],
            on: "var(--wc-color-on-primary)"
          ),
          text_token("color.on-primary", "Foreground on primary fills.", [
            "primary button text",
            "primary icon",
            "selected badge text"
          ]),
          fill_token(
            "color.accent",
            "Supporting action/accent fill or foreground.",
            ["secondary CTA", "selected lower-emphasis action", "editorial flourish"],
            on: "var(--wc-color-on-accent)"
          ),
          fill_token(
            "color.accent-hover",
            "Hover state for accent actions.",
            ["accent button hover", "accent link-card hover", "supporting CTA hover"],
            on: "var(--wc-color-on-accent)"
          ),
          fill_token(
            "color.accent-active",
            "Pressed state for accent actions.",
            ["accent button active", "mouse-down accent action", "supporting CTA active"],
            on: "var(--wc-color-on-accent)"
          ),
          text_token("color.on-accent", "Foreground on accent fills.", [
            "accent badge text",
            "special CTA text",
            "accent icon foreground"
          ]),
          fill_token(
            "color.danger",
            "Destructive action/error color.",
            ["delete button", "error icon", "invalid text"],
            on: "var(--wc-color-on-danger)"
          ),
          text_token("color.on-danger", "Foreground on danger fills.", [
            "destructive button text",
            "danger badge text",
            "critical icon foreground"
          ])
        ]
      },
      %{
        group: "Color",
        title: "Status",
        description:
          "Three tokens per status: foreground, tinted background, and border. Danger reuses the action color plus bg/border.",
        tokens: [
          status_token("color.success", "Success foreground.", [
            "saved state",
            "accepted invitation",
            "watched indicator"
          ]),
          status_token("color.success-bg", "Success tinted background.", [
            "success alert",
            "accepted badge",
            "saved banner"
          ]),
          status_token("color.success-border", "Success border.", [
            "success alert border",
            "accepted badge border",
            "watched indicator border"
          ]),
          status_token("color.warning", "Warning foreground.", [
            "spoiler warning",
            "expiring invite",
            "caution label"
          ]),
          status_token("color.warning-bg", "Warning tinted background.", [
            "warning alert",
            "archive suggestion",
            "spoiler callout"
          ]),
          status_token("color.warning-border", "Warning border.", [
            "warning alert border",
            "caution badge border",
            "archive callout border"
          ]),
          status_token("color.info", "Information foreground.", [
            "tip icon",
            "security notice",
            "system message"
          ]),
          status_token("color.info-bg", "Information tinted background.", [
            "info alert",
            "tip panel",
            "security notice"
          ]),
          status_token("color.info-border", "Information border.", [
            "info alert border",
            "tip border",
            "notice boundary"
          ]),
          status_token("color.danger-bg", "Danger tinted background.", [
            "error alert",
            "invalid field group",
            "delete warning panel"
          ]),
          status_token("color.danger-border", "Danger border.", [
            "invalid input",
            "error alert border",
            "delete zone border"
          ])
        ]
      },
      %{
        group: "Shape / size / elevation",
        title: "Non-color basics",
        description: "Only the repeated physical decisions we need immediately.",
        tokens: [
          radius_token("radius.control", "Default control radius.", [
            "buttons",
            "inputs",
            "select triggers"
          ]),
          radius_token("radius.card", "Default card/panel radius.", [
            "cards",
            "settings panels",
            "recommendation cards"
          ]),
          radius_token("radius.full", "Fully rounded shape.", ["badges", "avatars", "pills"]),
          size_token("size.control-sm", "Small control height.", [
            "filter buttons",
            "compact selects",
            "toolbar actions"
          ]),
          size_token("size.control-md", "Default control height.", [
            "inputs",
            "buttons",
            "selects"
          ]),
          size_token("size.control-lg", "Large control height.", [
            "auth forms",
            "primary setup actions",
            "mobile controls"
          ]),
          size_token("size.icon", "Default icon size.", [
            "button icons",
            "nav icons",
            "content type icons"
          ]),
          shadow_token("shadow.card", "Default card elevation.", [
            "content cards",
            "settings panels",
            "stats cards"
          ]),
          shadow_token("shadow.overlay", "Floating overlay elevation.", [
            "dialogs",
            "dropdowns",
            "popovers"
          ]),
          shadow_token("shadow.glow", "Brand glow for rare emphasis.", [
            "primary CTA",
            "selected feature",
            "hero action"
          ])
        ]
      }
    ]
  end

  defp background_token(name, meaning, use_cases) do
    %{name: name, kind: :background, meaning: meaning, use_cases: use_cases, preview_label: name}
  end

  defp text_token(name, meaning, use_cases) do
    %{name: name, kind: :text, meaning: meaning, use_cases: use_cases}
  end

  defp border_token(name, meaning, use_cases) do
    %{name: name, kind: :border, meaning: meaning, use_cases: use_cases}
  end

  defp fill_token(name, meaning, use_cases, opts) do
    %{name: name, kind: :fill, meaning: meaning, use_cases: use_cases, on: opts[:on]}
  end

  defp status_token(name, meaning, use_cases) do
    kind =
      cond do
        String.ends_with?(name, "-bg") -> :background
        String.ends_with?(name, "-border") -> :border
        true -> :text
      end

    %{name: name, kind: kind, meaning: meaning, use_cases: use_cases, preview_label: name}
  end

  defp radius_token(name, meaning, use_cases) do
    %{name: name, kind: :radius, meaning: meaning, use_cases: use_cases}
  end

  defp size_token(name, meaning, use_cases) do
    %{name: name, kind: :size, meaning: meaning, use_cases: use_cases}
  end

  defp shadow_token(name, meaning, use_cases) do
    %{name: name, kind: :shadow, meaning: meaning, use_cases: use_cases}
  end

  defp token_var(%{name: name}), do: token_var(name)
  defp token_var(name), do: "--wc-#{String.replace(name, ".", "-")}"

  defp recommendations do
    [
      rec(
        "The Shadow of the Wind",
        "Carlos Ruiz Zafón · book",
        "Book",
        "nate",
        false,
        {"Shadow", "#5a3d2b", "#17101c", "#f5d06f"}
      ),
      rec(
        "Three Billboards Outside Ebbing",
        "Martin McDonagh · movie",
        "Movie",
        "nate",
        true,
        {"Three", "#d8562b", "#211222", "#ff5555"}
      ),
      rec(
        "The Usual Suspects",
        "Bryan Singer · movie",
        "Movie",
        "nate",
        true,
        {"Usual", "#e8e1d5", "#11101a", "#8be9fd"}
      ),
      rec(
        "Blood Diamond",
        "Edward Zwick · movie",
        "Movie",
        "nate",
        false,
        {"Blood", "#f97316", "#2a0d14", "#ff5555"}
      ),
      rec(
        "Silicon Valley",
        "Mike Judge · show",
        "Show",
        "Jeremy",
        true,
        {"SV", "#f7f2e8", "#16121f", "#ff6b3d"}
      ),
      rec(
        "Ex Machina",
        "Alex Garland · movie",
        "Movie",
        "nate",
        true,
        {"EX", "#dce5ea", "#11101a", "#8be9fd"}
      ),
      rec(
        "Poor Things",
        "Yorgos Lanthimos · movie",
        "Movie",
        "nate",
        true,
        {"Poor", "#9fd2f3", "#2b1638", "#ff79c6"}
      ),
      rec(
        "Parasite",
        "Bong Joon-ho · movie",
        "Movie",
        "nate",
        true,
        {"Parasite", "#6ea37b", "#10121e", "#6ee7a7"}
      )
    ]
  end

  defp rec(title, subtitle, kind, by, watched, {poster_label, poster_a, poster_b, accent}) do
    %{
      title: title,
      subtitle: subtitle,
      kind: kind,
      by: by,
      watched: watched,
      poster_label: poster_label,
      poster_a: poster_a,
      poster_b: poster_b,
      accent: accent
    }
  end

  defp poster_style(item) do
    "background: radial-gradient(circle at 30% 18%, #{item.accent}, transparent 24%), linear-gradient(145deg, #{item.poster_a}, #{item.poster_b});"
  end
end
