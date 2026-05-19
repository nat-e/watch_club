defmodule WatchClubWeb.Storybook.Brainstorm.RelativeTimeCldr do
  @moduledoc """
  Temporary brainstorm mockup for CLDR-backed relative time formatting.

  Safe to delete after the design decision is accepted or rejected.
  """
  use PhoenixStorybook.Story, :page
  use Phoenix.Component

  import WatchClubWeb.Components.UI.Avatar
  import WatchClubWeb.Components.UI.Badge
  import WatchClubWeb.Components.UI.Table

  def doc do
    "Temporary brainstorm mockup comparing localized Member since values for English and French."
  end

  def render(assigns) do
    assigns =
      assign(assigns,
        english_rows: [
          %{
            id: "ada",
            user: "Ada Lovelace",
            role: "Admin",
            since: "now",
            invited_by_id: "grace",
            invited_by: "Grace Hopper"
          },
          %{
            id: "alan",
            user: "Alan Turing",
            role: "Member",
            since: "1 minute ago",
            invited_by_id: "ada",
            invited_by: "Ada Lovelace"
          },
          %{
            id: "katherine",
            user: "Katherine Johnson",
            role: "Member",
            since: "2 hours ago",
            invited_by_id: "grace",
            invited_by: "Grace Hopper"
          },
          %{
            id: "mary",
            user: "Mary Jackson",
            role: "Member",
            since: "3 weeks ago",
            invited_by_id: "ada",
            invited_by: "Ada Lovelace"
          },
          %{
            id: "dorothy",
            user: "Dorothy Vaughan",
            role: "Member",
            since: "Apr 19, 2026",
            invited_by_id: "grace",
            invited_by: "Grace Hopper"
          }
        ],
        french_rows: [
          %{
            id: "ada-fr",
            user: "Ada Lovelace",
            role: "Administrateur",
            since: "maintenant",
            invited_by_id: "grace-fr",
            invited_by: "Grace Hopper"
          },
          %{
            id: "alan-fr",
            user: "Alan Turing",
            role: "Membre",
            since: "il y a 1 minute",
            invited_by_id: "ada-fr",
            invited_by: "Ada Lovelace"
          },
          %{
            id: "katherine-fr",
            user: "Katherine Johnson",
            role: "Membre",
            since: "il y a 2 heures",
            invited_by_id: "grace-fr",
            invited_by: "Grace Hopper"
          },
          %{
            id: "mary-fr",
            user: "Mary Jackson",
            role: "Membre",
            since: "il y a 3 semaines",
            invited_by_id: "ada-fr",
            invited_by: "Ada Lovelace"
          },
          %{
            id: "dorothy-fr",
            user: "Dorothy Vaughan",
            role: "Membre",
            since: "19 avr. 2026",
            invited_by_id: "grace-fr",
            invited_by: "Grace Hopper"
          }
        ]
      )

    ~H"""
    <div class="theme-wc dark -m-8 min-h-screen bg-canvas p-page py-page-y text-text">
      <div class="mx-auto grid max-w-layout-page gap-section">
        <section class="grid gap-related rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
          <p class="text-sm font-medium text-primary">Brainstorm / temporary</p>
          <h1 class="text-3xl font-semibold tracking-tight">Localized relative time in Members</h1>
          <p class="max-w-readable text-sm leading-6 text-text-muted">
            Proposed behavior keeps the Members table structure unchanged while localizing the
            <span class="font-semibold text-text">Member since</span>
            value through CLDR. Dates older than four weeks become localized absolute dates.
          </p>
        </section>

        <div class="grid gap-cluster xl:grid-cols-2">
          <.locale_table
            title="English user locale"
            subtitle="Uses CLDR standard relative format and medium date format."
            rows={@english_rows}
          />
          <.locale_table
            title="French user locale"
            subtitle="Same thresholds; CLDR owns pluralization, word order, and date names."
            rows={@french_rows}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :rows, :list, required: true

  defp locale_table(assigns) do
    ~H"""
    <section class="grid gap-group rounded-card border border-border-subtle bg-surface p-cluster shadow-card">
      <div class="grid gap-tight">
        <h2 class="text-xl font-semibold tracking-tight">{@title}</h2>
        <p class="text-sm leading-6 text-text-muted">{@subtitle}</p>
      </div>

      <.table>
        <.table_header>
          <.table_row>
            <.table_head class="text-left">User</.table_head>
            <.table_head>Role</.table_head>
            <.table_head>Member since</.table_head>
            <.table_head class="text-left">Invited by</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :for={row <- @rows}>
            <.table_cell class="text-left">
              <div class="flex items-center gap-related font-bold">
                <.avatar id={"brainstorm-relative-time-#{row.id}"} name={row.user} />
                {row.user}
              </div>
            </.table_cell>
            <.table_cell>
              <.badge variant={
                if row.role in ["Admin", "Administrateur"], do: "default", else: "secondary"
              }>
                {row.role}
              </.badge>
            </.table_cell>
            <.table_cell class="text-text-subtle">{row.since}</.table_cell>
            <.table_cell class="text-left">
              <div class="flex items-center gap-related font-bold">
                <.avatar
                  id={"brainstorm-relative-time-inviter-#{row.invited_by_id}"}
                  name={row.invited_by}
                />
                {row.invited_by}
              </div>
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </section>
    """
  end
end
