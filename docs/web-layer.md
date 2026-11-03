# Web layer organization

How LiveViews and components are named, where they live, and when to use a LiveComponent. These rules override the Phoenix usage rules on LiveView names and on LiveComponents.

- Use LiveComponents when a component owns dedicated events, loading, streams, async work, or lifecycle/state boundaries. Do **not** create LiveComponents solely to split markup.
- Routed LiveViews should be named with a `Page` suffix and stored in files ending in `_page.ex`, for example `AppWeb.WeatherPage` in `weather_page.ex`.

## Component organization

- Organize the Phoenix web layer by ownership first, and use file suffixes to identify component type:
  - Routed LiveViews end in `_page.ex` and use a `Page` module suffix.
  - LiveComponents end in `_live.ex` and use a `Live` module suffix.
  - Function components have no component-type suffix.
- Generic reusable UI primitives live under `components/ui/` and are globally imported through a dedicated UI facade.
- Shared domain or application components live under `components/<domain>/` and must be imported explicitly where used.
- Routed pages and page-owned components live under `live/<domain>/<page>/`.
- `components/` contains both generic UI components and shared domain/application components. `live/` contains routed pages and components owned by those pages.
- Each component file exposes one public component by default. Tightly coupled semantic families may live together when their API is naturally one family, such as tables, dropdown menus, or avatar groups.
- Owner-private subcomponents usually stay as private function components in the owning file. They may be extracted for readability, especially once the subcomponent starts having its own subcomponents or meaningful helper logic.
- Extracted owner-private modules are imported only by their owner and are not globally registered.
- Shared function components must not hardcode LiveView server events. If a shared function component needs behavior, the caller must pass explicit assigns such as event names, targets, callbacks or JS commands; otherwise the component should be a LiveComponent that owns the interaction. Hardcoding client side JS commands that are scoped internally is allowed.
- Page-local components may hardcode page events because their event contract is owned by the page.
- `WatchClubWeb.Components` must not be used as a broad auto-import registry. UI primitives are globally available through the UI facade; shared domain components are explicit dependencies of the modules that use them.

Example shape:

    lib/watch_club_web/
      components/
        ui/
          button.ex
          modal.ex
          reorderable_list.ex
          icon_picker_live.ex

        contents/
          content_card.ex
          add_to_library_modal_live.ex

        navigation/
          navbar_live.ex
          sidebar_live.ex
          sidebar/
            create_club_modal.ex

      live/
        accounts/
          sign_in_page.ex
          setup_page.ex

        clubs/
          settings_page.ex
          settings/
            library_list.ex
            create_or_edit_library_modal.ex
            delete_library_modal.ex
