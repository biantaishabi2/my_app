defmodule MyAppWeb.FormLive.PageEditorComponent do
  use Phoenix.LiveComponent
  import MyAppWeb.CoreComponents
  
  alias MyApp.Forms
  alias MyApp.Forms.FormPage

  @impl true
  def mount(socket) do
    # Initialize state if needed, though most data comes via assigns
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Ensure we have a changeset, default to an empty one if not provided initially
    changeset = assigns[:page_changeset] || Forms.change_form_page(%FormPage{})

    socket =
      socket
      |> assign(assigns) # Assign all passed data
      |> assign_new(:page_changeset, fn -> changeset end) # Assign the changeset specifically

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        :let={f}
        for={@page_changeset}
        id="page-editor-form"
        phx-target={@myself}
        phx-submit="save_page"
        class="space-y-4"
      >
        <h3 class="text-lg font-medium leading-6 text-gray-900">
          <%= if @page_changeset.data.id, do: "编辑页面", else: "添加新页面" %>
        </h3>

        <.input field={f[:title]} type="text" label="页面名称" required />
        <.input field={f[:description]} type="textarea" label="页面描述 (可选)" />

        <div class="flex justify-end space-x-2 pt-4">
          <button
            type="button"
            phx-click="cancel_edit_page"
            phx-target={@myself}
            class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            取消
          </button>
          <.button type="submit">
            保存页面
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("save_page", %{"page" => page_params}, socket) do
    # Here you would typically send a message to the parent LiveView
    # to handle the actual saving logic, passing the page_params.
    # The parent LiveView (FormLive.Edit) owns the form_template data.

    # For now, just send a message to the parent.
    # The parent should handle changeset validation and persistence.
    send(self(), {:save_page_from_component, page_params})

    # Optionally, you could perform basic validation here first
    # and update the changeset locally if needed.

    {:noreply, socket}
  end
  
  # Handle form submission with form_page parameter (this is the format that comes from .form)
  @impl true
  def handle_event("save_page", %{"form_page" => page_params}, socket) do
    # Convert and send to parent using the same message format
    send(self(), {:save_page_from_component, page_params})
    {:noreply, socket}
  end

  # Handle cancellation - send message to parent to close the editor
  @impl true
  def handle_event("cancel_edit_page", _, socket) do
    send(self(), {:cancel_edit_page_from_component})
    {:noreply, socket}
  end
end
