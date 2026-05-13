defmodule WatchClubWeb.Storybook do
  use PhoenixStorybook,
    # OTP name of your application.
    otp_app: :watch_club,

    # Path to your storybook stories (required).
    content_path: Path.expand("storybook", __DIR__),

    # Path to your JS asset, which will be loaded just before PhoenixStorybook&#39;s own
    # JS. It&#39;s mainly intended to define your LiveView Hooks in `window.storybook.Hooks`.
    # Remote path (not local file-system path) which means this file should be served
    # by your own application endpoint.
    js_path: "/assets/js/storybook.js",

    # Path to your components stylesheet.
    # Remote path (not local file-system path) which means this file should be served by your own
    # application endpoint.
    # This stylesheet is loaded within the `app` CSS layer. Layer ordering is:
    # @layer reset, theme, app, utilities;
    css_path: "/assets/css/storybook.css",

    # This CSS class will be put on storybook container elements where your own styles should
    # prevail. See the `guides/sandboxing.md` guide for more details.
    # sandbox_class: "my-app-sandbox",

    # Custom storybook title. Default is "Live Storybook".
    title: "Watch Club Storybook",

    # Theme settings.
    # Each theme must have a name, and an optional dropdown_class.
    # When set, a dropdown is displayed in storybook header to let the user pick a theme.
    # The dropdown_class is used to render the theme in the dropdown and identify which current
    # theme is active.
    #
    # The chosen theme key will be passed as an assign to all components.
    # ex: <.component theme={:colorful}/>
    #
    # The chosen theme class will also be added to the `.psb-sandbox` container.
    # ex: <div class="psb-sandbox theme-colorful">...</div>
    #
    # If no theme has been selected or if no theme is present in the URL the first one is enabled.
    themes: [
      wc: [name: "Watch Club"]
    ],

    # Color mode settings. Defaults to false and &#39;dark&#39;.
    color_mode: true,
    color_mode_sandbox_dark_class: "dark",
    color_mode_sandbox_light_class: "light",

    # Set to `false` if you want to keep attributes & slot documentations in component page header.
    # Defaults to `true`.
    strip_doc_attributes: false

  # Story compilation mode, can be either `:eager` or `:lazy`.
  # It defaults to `:lazy` in dev environment, `:eager` in other environments.
  #   - When eager: all .story.exs & .index.exs files are compiled upfront.
  #   - When lazy: only .index.exs files are compiled upfront and .story.exs are compile when the
  #     matching story is loaded in UI.
  # compilation_mode: :eager,

  # If you want to see debugging logs for storybooks compilation, set this to `true`. Default: `false`
  # compilation_debug: true
end
