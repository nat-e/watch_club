defmodule WatchClubWeb.Storybook.SpacingLayout do
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Button
  import WatchClubWeb.Components.UI.Layout

  def doc do
    "Validated spacing, layout, and form guidelines for Watch Club."
  end

  def navigation do
    [
      {:overview, "Overview", {:fa, "ruler-combined"}},
      {:scale, "Scale", {:fa, "grip-lines"}},
      {:primitives, "Layout primitives", {:fa, "layer-group"}},
      {:forms, "Forms", {:fa, "pen-to-square"}},
      {:applied, "Applied", {:fa, "rectangle-ad"}}
    ]
  end

  def render(%{tab: :scale} = assigns) do
    assigns = assign(assigns, tokens: spacing_tokens())

    ~H"""
    <.page_shell>
      <.intro eyebrow="Spacing scale" title="A small set of relationship tokens">
        The scale stays close to the 4px Tailwind base but exposes semantic choices. Product code
        should ask for <em>relationship</em>, not a raw number.
      </.intro>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">Token ramp</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            These names are intentionally few. They cover dense component internals, related items,
            card/form grouping, subsections, and page-level rhythm.
          </p>
        </div>

        <div class="grid gap-group">
          <.scale_row :for={token <- @tokens} token={token} />
        </div>
      </section>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">How to choose</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            This is the rule that removes guesswork from screen implementation.
          </p>
        </div>

        <div class="grid gap-group md:grid-cols-2 xl:grid-cols-3">
          <.guideline_card
            token="space.tight"
            title="Inside small component parts"
            example="Icon + label, badge internals, compact affordances"
          />
          <.guideline_card
            token="space.related"
            title="Related things"
            example="Label + helper text, filter chips, small repeated controls"
          />
          <.guideline_card
            token="space.group"
            title="One component group"
            example="Card body, form fields, settings rows"
          />
          <.guideline_card
            token="space.cluster"
            title="Subsections in a surface"
            example="Modal header/body/footer rhythm, card sections"
          />
          <.guideline_card
            token="space.section"
            title="Major page regions"
            example="Hero to content, content to activity feed"
          />
          <.guideline_card
            token="space.page"
            title="Responsive page gutters"
            example="Outer page padding instead of ad-hoc px-4/px-8"
          />
        </div>
      </section>
    </.page_shell>
    """
  end

  def render(%{tab: :primitives} = assigns) do
    ~H"""
    <.page_shell>
      <.intro eyebrow="Layout primitives" title="Move spacing decisions to parent layout">
        Mature systems make screens compose structure. Child components should not push themselves
        around with random margins; the parent decides relationships. These validated primitives are
        the default building blocks for page rhythm, inline groups, wrapping clusters, and surfaces.
      </.intro>

      <div class="grid gap-cluster xl:grid-cols-2">
        <.primitive_card
          name="Stack"
          purpose="Vertical rhythm"
          code={stack_code()}
        >
          <.stack space="group" class="rounded-control border border-border-subtle bg-surface p-group">
            <.demo_item label="Club details" />
            <.demo_item label="Member permissions" />
            <.demo_item label="Danger zone" tone="danger" />
          </.stack>
        </.primitive_card>

        <.primitive_card
          name="Inline / Cluster"
          purpose="Horizontal groups that can wrap"
          code={inline_code()}
        >
          <.cluster class="rounded-control border border-border-subtle bg-surface p-group">
            <.badge variant="secondary">Drama</.badge>
            <.badge variant="secondary">Comedy</.badge>
            <.badge variant="secondary">Recently added</.badge>
            <.button id="spacing-inline-edit-filters-button" size="sm" variant="secondary">
              Edit filters
            </.button>
          </.cluster>
        </.primitive_card>

        <.primitive_card
          name="Page"
          purpose="Gutters, width, top/bottom rhythm"
          code={page_code()}
        >
          <div class="rounded-control border border-border-subtle bg-surface-inset p-related">
            <.page
              width="page"
              space="group"
              class="rounded-control border border-primary/40 bg-primary/10"
            >
              <div class="h-3 w-2/5 rounded-full bg-primary/70"></div>
              <div class="grid gap-related md:grid-cols-3">
                <div class="h-12 rounded-control bg-surface-raised"></div>
                <div class="h-12 rounded-control bg-surface-raised"></div>
                <div class="h-12 rounded-control bg-surface-raised"></div>
              </div>
            </.page>
          </div>
        </.primitive_card>

        <.primitive_card
          name="Section / Card"
          purpose="Section rhythm and surface padding"
          code={section_code()}
        >
          <.section
            space="section"
            class="rounded-control border border-border-subtle bg-surface-inset p-group"
          >
            <.demo_section title="Profile" />
            <.demo_section title="Watch preferences" />
          </.section>
        </.primitive_card>
      </div>
    </.page_shell>
    """
  end

  def render(%{tab: :forms} = assigns) do
    ~H"""
    <.page_shell>
      <.intro eyebrow="Forms" title="Start with two form primitives, not a full layout framework">
        I agree with keeping this narrower. Forms are where spacing consistency matters most, but
        we can get most of the benefit with a Watch Club <code>&lt;.form&gt;</code> wrapper and an
        improved <code>&lt;.field&gt;</code>. Sections and form groups can wait until repeated form
        structure proves they are needed.
      </.intro>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">Minimal v1 API</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            Keep Phoenix form semantics, but make the common spacing and submit-action layout the
            default. Field owns label/control/help/error rhythm.
          </p>
        </div>

        <div class="grid gap-cluster xl:grid-cols-2">
          <.form_api_card
            title="1. Watch Club form"
            badge="wrapper"
            code={form_wrapper_code()}
          >
            <ul class="grid gap-related text-sm leading-6 text-text-muted">
              <li>
                <strong class="text-text">Default layout:</strong> <code>grid gap-cluster</code>
              </li>
              <li>
                <strong class="text-text">Action slot:</strong>
                buttons render in a standardized action row
              </li>
              <li>
                <strong class="text-text">Still Phoenix:</strong>
                delegates to <code>Phoenix.Component.form/1</code>
              </li>
              <li>
                <strong class="text-text">Escape hatch:</strong>
                use <code>layout=&quot;none&quot;</code>
                for search bars and overlays
              </li>
            </ul>
          </.form_api_card>

          <.form_api_card title="2. Field" badge="replacement" code={field_wrapper_code()}>
            <ul class="grid gap-related text-sm leading-6 text-text-muted">
              <li>
                <strong class="text-text">Replaces:</strong> <code>&lt;.input_with_label&gt;</code>
              </li>
              <li><strong class="text-text">Default rhythm:</strong> label, input, hint, error</li>
              <li>
                <strong class="text-text">Flexible:</strong>
                accepts a custom control slot for select/radio/etc.
              </li>
            </ul>
          </.form_api_card>
        </div>
      </section>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">How a form would read</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            The screen no longer chooses <code>gap-6</code>, <code>gap-2</code>, or an ad-hoc button
            row. It expresses fields and actions.
          </p>
        </div>

        <div class="grid gap-cluster xl:grid-cols-[1fr_0.9fr]">
          <.code_block code={minimal_form_usage_code()} />

          <div class="rounded-card border border-border-subtle bg-canvas p-group">
            <.form_mock />
          </div>
        </div>
      </section>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">Spacing rules for forms</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            This gives us consistency now without introducing form sections or groups prematurely.
          </p>
        </div>

        <div class="grid gap-group md:grid-cols-2 xl:grid-cols-4">
          <.form_spacing_rule token="space.related" label="Label → control">
            The label and input are one related unit.
          </.form_spacing_rule>
          <.form_spacing_rule token="space.tight" label="Control → hint/error">
            Helper and validation copy stay visually attached to the control.
          </.form_spacing_rule>
          <.form_spacing_rule token="space.cluster" label="Field → field">
            The form wrapper separates standalone fields clearly.
          </.form_spacing_rule>
          <.form_spacing_rule token="space.related" label="Action → action">
            Cancel/save buttons use the same action-row rhythm everywhere.
          </.form_spacing_rule>
        </div>
      </section>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">Defer until repetition proves need</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            These are useful ideas, but adding them now would front-load API surface before we know
            our real form patterns.
          </p>
        </div>

        <div class="grid gap-group md:grid-cols-3">
          <.deferred_form_component name="<.form_group>">
            Add when multiple forms repeat grouped field clusters like name + role or password + confirmation.
          </.deferred_form_component>
          <.deferred_form_component name="<.form_section>">
            Add when pages repeat titled sections with descriptions, dividers, or section-level actions.
          </.deferred_form_component>
          <.deferred_form_component name="<.fieldset>">
            Add when we need semantic grouped controls with legends beyond what
            <code>&lt;.field&gt;</code>
            can express.
          </.deferred_form_component>
        </div>
      </section>
    </.page_shell>
    """
  end

  def render(%{tab: :applied} = assigns) do
    ~H"""
    <.page_shell>
      <.intro eyebrow="Applied screen" title="What screen code should feel like">
        The target is not fewer classes at all costs. The target is fewer arbitrary choices: the page
        chooses layout intent once, then content composes inside it.
      </.intro>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">Before / after</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            Raw Tailwind is still useful for mechanics, but repeated spacing decisions move to tokens
            and primitives.
          </p>
        </div>

        <div class="grid gap-cluster xl:grid-cols-2">
          <.comparison_panel title="Today" badge="raw values" tone="muted" code={before_code()}>
            <.raw_screen_mock />
          </.comparison_panel>

          <.comparison_panel
            title="Validated direction"
            badge="semantic layout"
            tone="primary"
            code={after_code()}
          >
            <.semantic_screen_mock />
          </.comparison_panel>
        </div>
      </section>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">Migration rule</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            Migrate one screen or component family at a time. Storybook documents the accepted
            spacing decisions before enforcement.
          </p>
        </div>

        <div class="grid gap-group md:grid-cols-3">
          <.migration_step number="1" title="Introduce tokens">
            Add semantic spacing aliases and use them in new Storybook examples.
          </.migration_step>
          <.migration_step number="2" title="Use primitives">
            Replace repeated layout wrappers with Page, Stack, Inline/Cluster, Section, and Card.
          </.migration_step>
          <.migration_step number="3" title="Enforce later">
            After migration, warn on raw spacing in feature screens while allowlisting UI primitives.
          </.migration_step>
        </div>
      </section>
    </.page_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <.page_shell>
      <.intro
        eyebrow="Spacing & layout system"
        title="Make spacing express relationships, not pixels"
      >
        Watch Club should still use Tailwind, but feature screens should stop choosing between <code>gap-2</code>, <code>gap-4</code>, and
        <code>p-6</code>
        by intuition. Tokens and layout
        primitives make the intent visible.
      </.intro>

      <div class="grid gap-cluster xl:grid-cols-[1fr_0.85fr]">
        <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
          <div class="grid gap-related">
            <h2 class="text-2xl font-semibold tracking-tight">Operating model</h2>
            <p class="max-w-readable text-sm leading-6 text-text-muted">
              This mirrors the pattern used by Carbon, Atlassian, GitLab Pajamas, Fluent, Polaris,
              and Spectrum: constrained scale, semantic usage rules, and parent-owned layout.
            </p>
          </div>

          <div class="grid gap-group md:grid-cols-3">
            <.principle_card
              title="Constrain choices"
              text="A short 4px/8px-compatible scale replaces one-off spacing values."
            />
            <.principle_card
              title="Name intent"
              text="Use related, group, cluster, and section to encode visual relationships."
            />
            <.principle_card
              title="Compose layout"
              text="Page, Stack, Inline, Section, and Card own repeated spacing patterns."
            />
          </div>
        </section>

        <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
          <div class="grid gap-related">
            <h2 class="text-2xl font-semibold tracking-tight">Validated v0 tokens</h2>
            <p class="text-sm leading-6 text-text-muted">
              These are available as Tailwind theme aliases and should be used in new form and layout work.
            </p>
          </div>

          <div class="grid gap-related">
            <.token_pill token="space.tight" value="4px" />
            <.token_pill token="space.related" value="8px" />
            <.token_pill token="space.group" value="16px" />
            <.token_pill token="space.cluster" value="24px" />
            <.token_pill token="space.section" value="48px" />
            <.token_pill token="space.page" value="responsive" />
          </div>
        </section>
      </div>

      <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
        <div class="grid gap-related">
          <h2 class="text-2xl font-semibold tracking-tight">The rule in one picture</h2>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            Closer things are more related. Larger gaps create section breaks and hierarchy.
          </p>
        </div>

        <div class="grid gap-section rounded-control border border-border-subtle bg-surface-inset p-group md:grid-cols-3">
          <.relationship_demo title="Related" space="related" />
          <.relationship_demo title="Grouped" space="group" />
          <.relationship_demo title="Sectioned" space="cluster" />
        </div>
      </section>
    </.page_shell>
    """
  end

  slot :inner_block, required: true

  defp page_shell(assigns) do
    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen bg-canvas px-page py-page-y text-text">
      <div class="mx-auto grid max-w-layout-page gap-section">
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
    <section class="grid gap-group rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
      <div class="grid gap-related">
        <p class="text-xs font-semibold uppercase tracking-[0.28em] text-accent">{@eyebrow}</p>
        <h1 class="max-w-4xl text-3xl font-semibold tracking-tight md:text-5xl">{@title}</h1>
      </div>
      <p class="max-w-readable text-base leading-7 text-text-muted [&_code]:rounded [&_code]:bg-surface-inset [&_code]:px-1.5 [&_code]:py-0.5 [&_em]:text-text">
        {render_slot(@inner_block)}
      </p>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :text, :string, required: true

  defp principle_card(assigns) do
    ~H"""
    <article class="grid gap-related rounded-control border border-border-subtle bg-surface-raised p-group">
      <div class="inline-flex size-8 items-center justify-center rounded-control bg-primary/15 text-primary">
        <Lucideicons.sparkles class="size-4" />
      </div>
      <h3 class="font-semibold">{@title}</h3>
      <p class="text-sm leading-6 text-text-muted">{@text}</p>
    </article>
    """
  end

  attr :token, :string, required: true
  attr :value, :string, required: true

  defp token_pill(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-related rounded-control border border-border-subtle bg-surface-raised px-group py-related">
      <code class="text-sm font-semibold text-primary">{@token}</code>
      <span class="text-sm text-text-muted">{@value}</span>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :space, :string, values: ~w(related group cluster), required: true

  defp relationship_demo(assigns) do
    ~H"""
    <article class="grid rounded-control border border-border-subtle bg-surface p-group">
      <div class={["grid", gap_class(@space)]}>
        <div class="h-10 rounded-control bg-primary/25 ring-1 ring-primary/30"></div>
        <div class="h-10 rounded-control bg-primary/20 ring-1 ring-primary/25"></div>
        <div class="h-10 rounded-control bg-primary/15 ring-1 ring-primary/20"></div>
      </div>
      <div class="mt-group grid gap-tight">
        <h3 class="font-semibold">{@title}</h3>
        <p class="text-sm text-text-muted">Uses <code class="text-primary">gap-{@space}</code></p>
      </div>
    </article>
    """
  end

  attr :token, :map, required: true

  defp scale_row(assigns) do
    ~H"""
    <article class="grid gap-group rounded-control border border-border-subtle bg-surface-raised p-group md:grid-cols-[14rem_1fr] md:items-center">
      <div class="grid gap-tight">
        <code class="font-semibold text-primary">{@token.name}</code>
        <span class="text-sm text-text-muted">{@token.value} · {@token.utility}</span>
      </div>

      <div class="grid gap-related">
        <div class="h-5 rounded-full bg-surface-inset p-1">
          <div class="h-full rounded-full bg-primary/70" style={"width: #{scale_width(@token)}"}>
          </div>
        </div>
        <p class="text-sm leading-6 text-text-muted">{@token.usage}</p>
      </div>
    </article>
    """
  end

  attr :token, :string, required: true
  attr :title, :string, required: true
  attr :example, :string, required: true

  defp guideline_card(assigns) do
    ~H"""
    <article class="grid gap-related rounded-control border border-border-subtle bg-surface-raised p-group">
      <code class="w-fit rounded bg-surface-inset px-2 py-1 text-xs font-semibold text-primary">
        {@token}
      </code>
      <div class="grid gap-tight">
        <h3 class="font-semibold">{@title}</h3>
        <p class="text-sm leading-6 text-text-muted">{@example}</p>
      </div>
    </article>
    """
  end

  attr :name, :string, required: true
  attr :purpose, :string, required: true
  attr :code, :string, required: true
  slot :inner_block, required: true

  defp primitive_card(assigns) do
    ~H"""
    <section class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
      <div class="flex flex-wrap items-start justify-between gap-group">
        <div class="grid gap-tight">
          <h2 class="text-2xl font-semibold tracking-tight">{@name}</h2>
          <p class="text-sm text-text-muted">{@purpose}</p>
        </div>
        <.badge variant="muted" size="sm">validated primitive</.badge>
      </div>

      <div class="rounded-control border border-border-subtle bg-surface-inset p-group">
        {render_slot(@inner_block)}
      </div>

      <.code_block code={@code} />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, values: ~w(default danger), default: "default"

  defp demo_item(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between gap-related rounded-control border px-group py-related",
      @tone == "default" && "border-border-subtle bg-surface-raised",
      @tone == "danger" && "border-danger-border bg-danger-bg text-danger"
    ]}>
      <span class="font-medium">{@label}</span>
      <span class="size-2 rounded-full bg-current opacity-60"></span>
    </div>
    """
  end

  attr :title, :string, required: true

  defp demo_section(assigns) do
    ~H"""
    <section class="grid gap-related rounded-control border border-border-subtle bg-surface p-group">
      <h3 class="font-semibold">{@title}</h3>
      <div class="grid gap-related">
        <div class="h-3 w-2/3 rounded-full bg-surface-raised"></div>
        <div class="h-3 w-1/2 rounded-full bg-surface-raised"></div>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :badge, :string, required: true
  attr :code, :string, required: true
  slot :inner_block, required: true

  defp form_api_card(assigns) do
    ~H"""
    <article class="grid gap-group rounded-card border border-border-subtle bg-surface-raised p-group">
      <div class="flex flex-wrap items-center justify-between gap-group">
        <h3 class="text-xl font-semibold">{@title}</h3>
        <.badge variant="muted" size="sm">{@badge}</.badge>
      </div>
      <div class="rounded-control border border-border-subtle bg-surface p-group">
        {render_slot(@inner_block)}
      </div>
      <.code_block code={@code} />
    </article>
    """
  end

  defp form_mock(assigns) do
    ~H"""
    <form
      id="spacing-form-mock"
      class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-cluster shadow-card"
    >
      <div class="grid gap-related">
        <h3 class="text-xl font-semibold">Create library</h3>
        <p class="text-sm leading-6 text-text-muted">
          Add a new library to this club. Choose one or more accepted content types.
        </p>
      </div>

      <.field_mock
        id="spacing-layout-library-name-input"
        label="Library name"
        hint="Use a name members will recognize."
      />
      <.field_mock
        label="Accepted content types"
        control="checkbox"
        error="Choose at least one accepted content type."
      />

      <div class="flex flex-col-reverse gap-related border-t border-border-subtle pt-group sm:flex-row sm:justify-end">
        <.button id="spacing-form-mock-cancel-button" type="button" variant="secondary">
          Cancel
        </.button>
        <.button id="spacing-form-mock-create-library-button" type="button">Create library</.button>
      </div>
    </form>
    """
  end

  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :error, :string, default: nil
  attr :control, :string, values: ~w(input checkbox), default: "input"

  defp field_mock(assigns) do
    ~H"""
    <div class="grid gap-related">
      <label for={@id} class="text-sm font-medium leading-none text-text">{@label}</label>

      <input
        :if={@control == "input"}
        id={@id}
        class="h-control-md rounded-control border border-border bg-surface-inset px-3 py-2 text-sm text-text outline-none"
        value="Weekend watchlist"
        readonly
      />

      <div :if={@control == "checkbox"} class="grid gap-related sm:grid-cols-3">
        <label class="grid cursor-pointer grid-cols-[auto_1fr] items-center gap-related rounded-control border border-primary bg-surface-selected p-group text-sm">
          <span class="size-3 rounded-[3px] border border-primary bg-primary"></span> Movies
        </label>
        <label class="grid cursor-pointer grid-cols-[auto_1fr] items-center gap-related rounded-control border border-primary bg-surface-selected p-group text-sm">
          <span class="size-3 rounded-[3px] border border-primary bg-primary"></span> Shows
        </label>
        <label class="grid cursor-pointer grid-cols-[auto_1fr] items-center gap-related rounded-control border border-border bg-surface-inset p-group text-sm">
          <span class="size-3 rounded-[3px] border border-border"></span> Books
        </label>
      </div>

      <p :if={@hint} class="text-sm leading-6 text-text-muted">{@hint}</p>
      <p :if={@error} class="text-sm leading-6 text-danger">{@error}</p>
    </div>
    """
  end

  attr :token, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp form_spacing_rule(assigns) do
    ~H"""
    <article class="grid gap-related rounded-control border border-border-subtle bg-surface-raised p-group">
      <code class="w-fit rounded bg-surface-inset px-2 py-1 text-xs font-semibold text-primary">
        {@token}
      </code>
      <h3 class="font-semibold">{@label}</h3>
      <p class="text-sm leading-6 text-text-muted">{render_slot(@inner_block)}</p>
    </article>
    """
  end

  attr :name, :string, required: true
  slot :inner_block, required: true

  defp deferred_form_component(assigns) do
    ~H"""
    <article class="grid gap-related rounded-control border border-border-subtle bg-surface-raised p-group">
      <code class="w-fit rounded bg-surface-inset px-2 py-1 text-xs font-semibold text-text">
        {@name}
      </code>
      <p class="text-sm leading-6 text-text-muted [&_code]:rounded [&_code]:bg-surface-inset [&_code]:px-1.5 [&_code]:py-0.5">
        {render_slot(@inner_block)}
      </p>
    </article>
    """
  end

  attr :title, :string, required: true
  attr :badge, :string, required: true
  attr :tone, :string, values: ~w(muted primary), required: true
  attr :code, :string, required: true
  slot :inner_block, required: true

  defp comparison_panel(assigns) do
    ~H"""
    <article class="grid gap-group rounded-card border border-border-subtle bg-surface-raised p-group">
      <div class="flex items-center justify-between gap-group">
        <h3 class="text-xl font-semibold">{@title}</h3>
        <.badge variant={if(@tone == "primary", do: "default", else: "muted")} size="sm">
          {@badge}
        </.badge>
      </div>

      <div class="rounded-control border border-border-subtle bg-canvas p-group">
        {render_slot(@inner_block)}
      </div>

      <.code_block code={@code} />
    </article>
    """
  end

  defp raw_screen_mock(assigns) do
    ~H"""
    <div class="mx-auto grid max-w-md gap-6 p-4">
      <div class="grid gap-2">
        <div class="h-6 w-2/3 rounded-full bg-primary/70"></div>
        <div class="h-3 w-full rounded-full bg-surface-raised"></div>
      </div>

      <div class="grid gap-4 rounded-card border border-border-subtle bg-surface p-4">
        <div class="flex items-center gap-2">
          <div class="size-10 rounded-full bg-surface-raised"></div>
          <div class="grid flex-1 gap-1">
            <div class="h-3 w-1/2 rounded-full bg-text-muted/60"></div>
            <div class="h-3 w-1/3 rounded-full bg-text-subtle/50"></div>
          </div>
        </div>
        <div class="grid gap-2">
          <div class="h-9 rounded-control bg-surface-inset"></div>
          <div class="h-9 rounded-control bg-surface-inset"></div>
        </div>
      </div>

      <div class="grid gap-4 rounded-card border border-border-subtle bg-surface p-4">
        <div class="h-4 w-1/2 rounded-full bg-primary/60"></div>
        <div class="grid gap-2">
          <div class="h-12 rounded-control bg-surface-inset"></div>
          <div class="h-12 rounded-control bg-surface-inset"></div>
        </div>
      </div>
    </div>
    """
  end

  defp semantic_screen_mock(assigns) do
    ~H"""
    <div class="mx-auto grid max-w-panel gap-section px-page py-page-y">
      <div class="grid gap-related">
        <div class="h-6 w-2/3 rounded-full bg-primary/70"></div>
        <div class="h-3 w-full rounded-full bg-surface-raised"></div>
      </div>

      <div class="grid gap-group rounded-card border border-border-subtle bg-surface p-group">
        <div class="flex items-center gap-related">
          <div class="size-10 rounded-full bg-surface-raised"></div>
          <div class="grid flex-1 gap-tight">
            <div class="h-3 w-1/2 rounded-full bg-text-muted/60"></div>
            <div class="h-3 w-1/3 rounded-full bg-text-subtle/50"></div>
          </div>
        </div>
        <div class="grid gap-related">
          <div class="h-9 rounded-control bg-surface-inset"></div>
          <div class="h-9 rounded-control bg-surface-inset"></div>
        </div>
      </div>

      <div class="grid gap-cluster rounded-card border border-border-subtle bg-surface p-group">
        <div class="h-4 w-1/2 rounded-full bg-primary/60"></div>
        <div class="grid gap-related">
          <div class="h-12 rounded-control bg-surface-inset"></div>
          <div class="h-12 rounded-control bg-surface-inset"></div>
        </div>
      </div>
    </div>
    """
  end

  attr :number, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp migration_step(assigns) do
    ~H"""
    <article class="grid gap-related rounded-control border border-border-subtle bg-surface-raised p-group">
      <div class="inline-flex size-8 items-center justify-center rounded-full bg-primary text-sm font-bold text-on-primary">
        {@number}
      </div>
      <h3 class="font-semibold">{@title}</h3>
      <p class="text-sm leading-6 text-text-muted">{render_slot(@inner_block)}</p>
    </article>
    """
  end

  attr :code, :string, required: true

  defp code_block(assigns) do
    ~H"""
    <pre class="overflow-x-auto rounded-control border border-border-subtle bg-surface-inset p-group text-xs leading-6 text-text-muted"><code class="whitespace-pre">{@code}</code></pre>
    """
  end

  defp spacing_tokens do
    [
      %{
        name: "space.tight",
        value: "4px",
        pixel: 4,
        utility: "gap-tight / p-tight",
        usage: "Dense spacing inside small component parts, such as icon/text pairs."
      },
      %{
        name: "space.related",
        value: "8px",
        pixel: 8,
        utility: "gap-related / p-related",
        usage: "Closely related elements: label/helper text, chips, compact repeated controls."
      },
      %{
        name: "space.group",
        value: "16px",
        pixel: 16,
        utility: "gap-group / p-group",
        usage: "Default card, form, and settings row spacing."
      },
      %{
        name: "space.cluster",
        value: "24px",
        pixel: 24,
        utility: "gap-cluster / p-cluster",
        usage: "Subsections inside a surface, like modal content blocks."
      },
      %{
        name: "space.section",
        value: "48px",
        pixel: 48,
        utility: "gap-section / py-section",
        usage: "Major page regions and hierarchy breaks."
      },
      %{
        name: "space.page",
        value: "fluid",
        pixel: 64,
        utility: "px-page / py-page-y",
        usage: "Responsive outer page gutters and vertical page rhythm."
      }
    ]
  end

  defp scale_width(%{pixel: pixel}), do: "#{max(pixel * 3, 12)}px"

  defp gap_class("tight"), do: "gap-tight"
  defp gap_class("related"), do: "gap-related"
  defp gap_class("group"), do: "gap-group"
  defp gap_class("cluster"), do: "gap-cluster"
  defp gap_class("section"), do: "gap-section"

  defp stack_code do
    """
    <.stack space="group">
      <.settings_section />
      <.permissions_section />
      <.danger_zone />
    </.stack>
    """
    |> String.trim()
  end

  defp inline_code do
    """
    <.cluster space="related">
      <.badge>Drama</.badge>
      <.badge>Comedy</.badge>
      <.button id="edit-filters-button" size="sm" variant="secondary">Edit filters</.button>
    </.cluster>
    """
    |> String.trim()
  end

  defp page_code do
    """
    <.page width="page" space="section">
      <.page_header />
      <.content_grid />
    </.page>
    """
    |> String.trim()
  end

  defp section_code do
    """
    <.section space="section">
      <.card>
        <.stack space="cluster">
          ...
        </.stack>
      </.card>
    </.section>
    """
    |> String.trim()
  end

  defp form_wrapper_code do
    """
    <.form for={@form} id="example-form" phx-submit="save">
      ...fields...

      <:action>
        <.button id="example-cancel-button" variant="secondary">Cancel</.button>
        <.button id="example-save-button">Save</.button>
      </:action>
    </.form>
    """
    |> String.trim()
  end

  defp field_wrapper_code do
    """
    <.field field={@form[:name]} label="Club name" />

    <.field field={@form[:role]} label="Role">
      <:control>
        <.select id="role-select" field={@form[:role]} options={@roles} />
      </:control>
      <:hint>Admins can invite members.</:hint>
    </.field>
    """
    |> String.trim()
  end

  defp minimal_form_usage_code do
    """
    <.form
      for={@form}
      id="create-library-form"
      phx-change="validate_create_library"
      phx-submit="submit_create_library"
    >
      <.field field={@form[:name]} label="Library name">
        <:hint>Use a name members will recognize.</:hint>
      </.field>

      <.field field={@form[:accepted_content_types]} label="Accepted content types">
        <:control>
          <div class="grid grid-cols-1 gap-related sm:grid-cols-3">
            ...
          </div>
        </:control>
      </.field>

      <:action>
        <.button id="create-library-cancel-button" type="button" variant="secondary">Cancel</.button>
        <.button id="create-library-submit-button" type="submit">Create library</.button>
      </:action>
    </.form>
    """
    |> String.trim()
  end

  defp before_code do
    """
    <div class="mx-auto grid max-w-md gap-6 p-4">
      <div class="grid gap-2">...</div>
      <div class="grid gap-4 rounded-card p-4">...</div>
    </div>
    """
    |> String.trim()
  end

  defp after_code do
    """
    <.page width="panel">
      <.stack space="section">
        <.page_header />
        <.card>
          <.stack space="group">...</.stack>
        </.card>
      </.stack>
    </.page>
    """
    |> String.trim()
  end
end
