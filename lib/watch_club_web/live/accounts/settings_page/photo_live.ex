defmodule WatchClubWeb.Accounts.SettingsPage.PhotoLive do
  @moduledoc """
  The User's photo and Username, heading Settings. The camera button picks a photo, or removes
  it. A picked photo opens a dialog to crop it in a circle: the browser crops it, then uploads the
  square, which `Accounts.set_photo/3` re-encodes.
  """
  use WatchClubWeb, :live_component

  import WatchClubWeb.Components.Accounts.UserAvatar

  alias WatchClubWeb.Hooks.Flash

  attr :current_user, User, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col gap-group">
      <%!-- The browser opens the picked photo itself: only its crop is uploaded. Ignored by
      LiveView, which would clear it. --%>
      <input
        id={"#{@id}-file"}
        type="file"
        accept="image/*"
        class="hidden"
        phx-hook=".PhotoPicker"
        phx-update="ignore"
        phx-target={@myself}
      />
      <.form
        for={%{}}
        id={"#{@id}-upload"}
        phx-change="validate_upload"
        phx-target={@myself}
        class="hidden"
      >
        <.live_file_input upload={@uploads.photo} />
      </.form>

      <div class="flex items-center gap-group">
        <div class="relative shrink-0">
          <.user_avatar user={@current_user} size="xl" />
          <%!-- Adding or removing the photo swaps the camera button: focus moves to the new one --%>
          <div class="absolute -right-tight -bottom-tight">
            <%!-- With no photo to remove, the camera button picks one at once --%>
            <.camera_button
              :if={!@current_user.photo_revision}
              id={"#{@id}-pick"}
              label={dgettext("settings", "Upload photo")}
              phx-click={pick_photo(@id)}
              phx-mounted={@refocus_camera? && JS.focus()}
            />
            <.dropdown_menu :if={@current_user.photo_revision} id={"#{@id}-menu"}>
              <:trigger>
                <.camera_button
                  id={"#{@id}-menu-button"}
                  label={dgettext("settings", "Change photo")}
                  phx-mounted={@refocus_camera? && JS.focus()}
                />
              </:trigger>
              <.dropdown_menu_item id={"#{@id}-menu-pick"} phx-click={pick_photo(@id)}>
                <Lucideicons.upload />{dgettext("settings", "Upload photo")}
              </.dropdown_menu_item>
              <.dropdown_menu_item
                id={"#{@id}-menu-remove"}
                variant="destructive"
                phx-click="remove"
                phx-target={@myself}
              >
                <Lucideicons.trash_2 />{dgettext("settings", "Remove photo")}
              </.dropdown_menu_item>
            </.dropdown_menu>
          </div>
        </div>
        <div class="flex min-w-0 flex-col">
          <span class="truncate font-heading text-2xl font-semibold">{@current_user.username}</span>
          <span :if={@current_user.administrator?} class="truncate text-sm text-text-muted">
            {dgettext("nav", "Instance administrator")}
          </span>
        </div>
      </div>
      <.field_errors errors={@pick_errors} role="alert" />

      <.crop_modal
        :if={@cropping?}
        id={"#{@id}-crop"}
        file_input={"#{@id}-file"}
        upload_form={"#{@id}-upload"}
        saving?={@uploads.photo.entries != []}
        errors={@save_errors}
        myself={@myself}
      />

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PhotoPicker">
        // Opens the crop dialog for a photo the browser can open
        export default {
          mounted() {
            this.el.addEventListener("change", async () => {
              const [file] = this.el.files;
              if (!file) return;

              const url = URL.createObjectURL(file);
              const image = new Image();
              image.src = url;

              try {
                await image.decode();
                this.pushEventTo(this.el, "crop", {});
              } catch {
                this.el.value = "";
                this.pushEventTo(this.el, "unreadable", {});
              } finally {
                URL.revokeObjectURL(url);
              }
            });
          },
        };
      </script>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :file_input, :string, required: true, doc: "the id of the input with the picked photo"
  attr :upload_form, :string, required: true, doc: "the id of the form uploading the crop"
  attr :saving?, :boolean, required: true
  attr :errors, :list, required: true
  attr :myself, :any, required: true

  # Cropper.js shows the picked photo under a circle: the User moves and zooms it, then the hook
  # uploads the circle's square
  defp crop_modal(assigns) do
    ~H"""
    <.modal
      id={@id}
      size="sm"
      phone="full_screen"
      class="w-full"
      on_close={JS.push("cancel", target: @myself)}
    >
      <:title>{dgettext("settings", "Crop your photo")}</:title>
      <%!-- Cropper.js owns this part of the page --%>
      <div
        id={"#{@id}-cropper"}
        phx-hook=".PhotoCropper"
        phx-update="ignore"
        data-file-input={@file_input}
        data-upload-form={@upload_form}
        data-save={"#{@id}-save"}
        data-saving={to_string(@saving?)}
        class="flex flex-col gap-group"
      >
        <div
          role="group"
          tabindex="0"
          autofocus
          aria-label={dgettext("settings", "Your new photo. Move it with the arrow keys.")}
          data-stage
          class="relative mx-auto aspect-square w-80 max-w-full cursor-grab overflow-hidden rounded-card bg-black focus-visible:-outline-offset-2"
        >
          <cropper-canvas class="block size-full">
            <%!-- Dragging and pinching keep the image over the circle, 6% inside the stage --%>
            <cropper-image alt="" translatable scalable max-inset="6%"></cropper-image>
            <cropper-handle action="move" plain></cropper-handle>
            <%!-- A circle with the outside dimmed. Cropper.js still crops its square. --%>
            <cropper-selection
              aspect-ratio="1"
              class="pointer-events-none rounded-full shadow-[0_0_0_100vmax] shadow-black/60"
            >
            </cropper-selection>
          </cropper-canvas>
        </div>
        <p class="text-center text-text-muted pointer-coarse:hidden">
          {dgettext("settings", "Drag the photo, or click where to center it.")}
        </p>
        <p class="text-center text-text-muted pointer-fine:hidden">
          {dgettext("settings", "Drag the photo, or tap where to center it.")}
        </p>
        <fieldset data-zoom class="flex items-center gap-related">
          <.button
            id={"#{@id}-zoom-out"}
            variant="ghost"
            size="icon"
            aria-label={dgettext("settings", "Zoom out")}
            title={dgettext("settings", "Zoom out")}
            data-zoom-out
          >
            <Lucideicons.zoom_out />
          </.button>
          <input
            type="range"
            min="1"
            max="4"
            step="0.01"
            value="1"
            aria-label={dgettext("settings", "Zoom")}
            data-zoom-slider
            class="min-w-0 flex-1 accent-primary disabled:opacity-40"
          />
          <.button
            id={"#{@id}-zoom-in"}
            variant="ghost"
            size="icon"
            aria-label={dgettext("settings", "Zoom in")}
            title={dgettext("settings", "Zoom in")}
            data-zoom-in
          >
            <Lucideicons.zoom_in />
          </.button>
        </fieldset>
      </div>
      <.field_errors errors={@errors} role="alert" class="text-center" />
      <:footer class="max-md:mt-auto">
        <%!-- Cancelling while saving cancels the upload --%>
        <.button id={"#{@id}-cancel"} variant="secondary" data-modal-close>
          {dgettext("default", "Cancel")}
        </.button>
        <.button id={"#{@id}-save"} disabled={@saving?} aria-busy={@saving? && "true"}>
          <Lucideicons.loader_circle :if={@saving?} class="motion-safe:animate-spin" />
          {if @saving?,
            do: dgettext("settings", "Saving…"),
            else: dgettext("settings", "Save photo")}
        </.button>
      </:footer>
    </.modal>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhotoCropper">
      import "cropperjs";

      // The crop's size: the server re-encodes it smaller
      const OUTPUT_SIZE = 512;
      // The circle's margin in the stage, as the image's max-inset
      const INSET = 0.06;
      const MAX_ZOOM = 4;
      const ZOOM_STEP = 1.25;
      const ARROW_STEP = 10;

      export default {
        async mounted() {
          this.fileInput = document.getElementById(this.el.dataset.fileInput);
          this.stage = this.el.querySelector("[data-stage]");
          this.canvas = this.el.querySelector("cropper-canvas");
          this.image = this.el.querySelector("cropper-image");
          this.selection = this.el.querySelector("cropper-selection");
          this.slider = this.el.querySelector("[data-zoom-slider]");
          this.zoom = this.el.querySelector("[data-zoom]");

          this.url = URL.createObjectURL(this.fileInput.files[0]);
          this.image.src = this.url;
          await this.image.$ready();
          // The dialog lays out once it's open
          await new Promise(requestAnimationFrame);

          const size = this.canvas.clientWidth;
          const inset = size * INSET;
          this.circle = { left: inset, top: inset, size: size - 2 * inset };
          this.selection.$change(inset, inset, this.circle.size, this.circle.size);

          const { naturalWidth, naturalHeight } = this.image.$image;
          this.natural = { width: naturalWidth, height: naturalHeight };
          this.minScale = this.circle.size / Math.min(naturalWidth, naturalHeight);
          // Covers the stage, not only the circle
          this.zoomTo((this.minScale * size) / this.circle.size);

          this.image.addEventListener("transform", (event) => {
            // Pinching and the mouse wheel zoom in no further than the slider
            if (event.detail.matrix[0] > this.minScale * MAX_ZOOM * 1.001) event.preventDefault();
            requestAnimationFrame(() => this.syncSlider());
          });
          this.slider.addEventListener("input", () =>
            this.zoomTo(this.minScale * this.slider.valueAsNumber),
          );
          this.el
            .querySelector("[data-zoom-in]")
            .addEventListener("click", () => this.zoomTo(this.scale() * ZOOM_STEP));
          this.el
            .querySelector("[data-zoom-out]")
            .addEventListener("click", () => this.zoomTo(this.scale() / ZOOM_STEP));
          this.stage.addEventListener("keydown", (event) => this.moveWithKeys(event));
          this.stage.addEventListener("pointerdown", (event) => {
            this.pointerDown = { x: event.clientX, y: event.clientY };
          });
          this.stage.addEventListener("click", (event) => this.centerOnClick(event));

          this.onSave = () => this.save();
          this.saveButton = document.getElementById(this.el.dataset.save);
          this.saveButton.addEventListener("click", this.onSave);
        },

        updated() {
          this.zoom.disabled = this.el.dataset.saving === "true";
        },

        destroyed() {
          // A crop still encoding when the dialog closes isn't uploaded
          this.closed = true;
          this.saveButton?.removeEventListener("click", this.onSave);
          if (this.url) URL.revokeObjectURL(this.url);
          // Picking the same file again opens the dialog again
          this.fileInput.value = "";
        },

        scale() {
          return this.image.$getTransform()[0];
        },

        // The image's top-left corner in the stage
        origin() {
          const image = this.image.getBoundingClientRect();
          const canvas = this.canvas.getBoundingClientRect();
          return { left: image.left - canvas.left, top: image.top - canvas.top };
        },

        // Shows the image at `scale`, its top-left corner at (left, top) in the stage, moved as
        // little as needed to cover the circle, as max-inset requires
        place(scale, left, top) {
          const { width, height } = this.natural;
          const { left: circleLeft, top: circleTop, size } = this.circle;
          const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
          const x = clamp(left, circleLeft + size - width * scale, circleLeft);
          const y = clamp(top, circleTop + size - height * scale, circleTop);

          // Cropper.js transforms the image around its center
          this.image.$setTransform(
            scale,
            0,
            0,
            scale,
            x - width / 2 + (width * scale) / 2,
            y - height / 2 + (height * scale) / 2,
          );
          this.syncSlider();
        },

        // Zooms around the circle's center
        zoomTo(target) {
          const scale = Math.min(Math.max(target, this.minScale), this.minScale * MAX_ZOOM);
          const current = this.scale();
          const origin = this.origin();
          const centerX = this.circle.left + this.circle.size / 2;
          const centerY = this.circle.top + this.circle.size / 2;

          this.place(
            scale,
            centerX - ((centerX - origin.left) / current) * scale,
            centerY - ((centerY - origin.top) / current) * scale,
          );
        },

        moveBy(dx, dy) {
          const origin = this.origin();
          this.place(this.scale(), origin.left + dx, origin.top + dy);
        },

        moveWithKeys(event) {
          const moves = {
            ArrowLeft: [-1, 0],
            ArrowRight: [1, 0],
            ArrowUp: [0, -1],
            ArrowDown: [0, 1],
          };
          const move = moves[event.key];
          if (!move) return;
          event.preventDefault();
          this.moveBy(move[0] * ARROW_STEP, move[1] * ARROW_STEP);
        },

        // A click or tap that isn't the end of a drag centers the circle on that point
        centerOnClick(event) {
          const start = this.pointerDown;
          if (!start || Math.hypot(event.clientX - start.x, event.clientY - start.y) > 4) return;

          const canvas = this.canvas.getBoundingClientRect();
          const { left, top, size } = this.circle;
          this.moveBy(
            left + size / 2 - (event.clientX - canvas.left),
            top + size / 2 - (event.clientY - canvas.top),
          );
        },

        syncSlider() {
          const zoom = this.scale() / this.minScale;
          this.slider.value = zoom;
          this.slider.setAttribute("aria-valuetext", `${Math.round(zoom * 100)}%`);
        },

        async save() {
          const canvas = await this.selection.$toCanvas({ width: OUTPUT_SIZE, height: OUTPUT_SIZE });
          const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.9));
          if (this.closed) return;
          const form = document.getElementById(this.el.dataset.uploadForm);
          this.uploadTo(form, "photo", [new File([blob], "photo.jpg", { type: "image/jpeg" })]);
        },
      };
    </script>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :rest, :global

  defp camera_button(assigns) do
    ~H"""
    <.button
      id={@id}
      variant="secondary"
      size="icon-sm"
      class="rounded-full! ring-2 ring-canvas pointer-coarse:size-touch-target!"
      aria-label={@label}
      title={@label}
      {@rest}
    >
      <Lucideicons.camera />
    </.button>
    """
  end

  defp pick_photo(id), do: JS.dispatch("click", to: "##{id}-file")

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(cropping?: false, pick_errors: [], save_errors: [], refocus_camera?: false)
     |> allow_upload(:photo,
       accept: ~w(.jpg .jpeg),
       max_entries: 1,
       # The crop is a 512px JPEG
       max_file_size: 1_000_000,
       auto_upload: true,
       progress: &save_photo/3
     )}
  end

  @impl true
  def handle_event("crop", _params, socket),
    do: {:noreply, assign(socket, cropping?: true, pick_errors: [], save_errors: [])}

  def handle_event("unreadable", _params, socket) do
    {:noreply,
     assign(socket, :pick_errors, [
       dgettext("errors", "We can't open this file. Choose a JPEG, PNG or WebP photo.")
     ])}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply,
     socket
     |> cancel_uploads()
     |> assign(cropping?: false, save_errors: [])}
  end

  def handle_event("validate_upload", _params, socket),
    do: {:noreply, fail_rejected_upload(socket)}

  def handle_event("remove", _params, socket) do
    user = socket.assigns.current_user
    Accounts.remove_photo!(user, actor: user)
    Flash.send_flash(:success, dgettext("settings", "Your photo is removed"))
    {:noreply, assign(socket, pick_errors: [], refocus_camera?: true)}
  end

  # The User's pages reload their avatar once the photo is saved, this one included
  defp save_photo(:photo, %{done?: true} = entry, socket) do
    user = socket.assigns.current_user

    result =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        {:ok, Accounts.set_photo(user, Ash.Type.File.from_path(path), actor: user)}
      end)

    case result do
      {:ok, _user} ->
        Flash.send_flash(:success, dgettext("settings", "Your photo is saved"))
        {:noreply, assign(socket, cropping?: false, refocus_camera?: true)}

      {:error, _error} ->
        {:noreply, assign(socket, :save_errors, [save_error()])}
    end
  end

  defp save_photo(:photo, _entry, socket), do: {:noreply, fail_rejected_upload(socket)}

  # Only the crop is uploaded, which fits the upload's limits: a rejected or failed upload is a
  # failed save
  defp fail_rejected_upload(socket) do
    upload = socket.assigns.uploads.photo

    if Enum.any?(upload.entries, &(upload_errors(upload, &1) != [])),
      do: socket |> cancel_uploads() |> assign(:save_errors, [save_error()]),
      else: socket
  end

  defp save_error, do: dgettext("settings", "We couldn't save your photo. Try again.")

  defp cancel_uploads(socket) do
    Enum.reduce(socket.assigns.uploads.photo.entries, socket, &cancel_upload(&2, :photo, &1.ref))
  end
end
