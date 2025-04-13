defmodule MyAppWeb.Live.DebugParentLive do
  use MyAppWeb, :live_view
  alias MyAppWeb.Components.DebugRendererComponent
  alias MyAppWeb.Components.DebugChildComponent
  require Logger # Use Logger instead of IO.puts for better integration

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        data: %{"item_A" => "initial", "item_B" => "initial", "item_C" => "initial"}, # Simulate multiple items data
        jump_state: %{active: false, source_id: nil, target_id: nil} # Use jump_state map
      )
    Logger.info("[Parent mount] Initial state assigned")
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-4">Debug Parent LiveView</h1>

      <div class="mb-4 p-2 border bg-gray-100">
        <p>Parent State:</p>
        <pre><code>Data: <%= inspect(@data) %></code></pre>
        <pre><code>Jump State: <%= inspect(@jump_state) %></code></pre> <%# Display jump_state %>
      </div>

      <button phx-click="trigger_update_A" class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 mr-2">
        Click Item A (Should Jump A -> C)
      </button>
      <button phx-click="reset_jump" class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600">
        Reset Jump
      </button>

      <hr class="my-6">

      <.live_component
        module={MyAppWeb.Components.DebugRendererComponent}
        id="renderer-debug-component"
        data={@data}
        jump_state={@jump_state} # Pass jump_state
      />
    </div>
    """
  end

  @impl true
  def handle_event("trigger_update_A", _value, socket) do
    Logger.info("[Parent handle_event] trigger_update_A received")
    # Simulate clicking item A updates its value and triggers jump A -> C
    source_id = "item_A"
    target_id = "item_C"
    new_value = "clicked_A_#{System.unique_integer([:positive])}"

    updated_data = Map.put(socket.assigns.data, source_id, new_value)
    updated_jump_state = %{active: true, source_id: source_id, target_id: target_id}

    Logger.info("[Parent handle_event] Updating data to: #{inspect(updated_data)}")
    Logger.info("[Parent handle_event] Updating jump_state to: #{inspect(updated_jump_state)}")

    new_assigns = %{
      data: updated_data,
      jump_state: updated_jump_state
    }
    Logger.debug("[Parent handle_event] FINAL assigns before update: #{inspect(new_assigns)}")

    {:noreply, assign(socket, new_assigns)}
  end

  @impl true
  def handle_event("reset_jump", _value, socket) do
    Logger.info("[Parent handle_event] reset_jump received")
    # Reset jump state and maybe data if needed
    initial_data = %{"item_A" => "initial", "item_B" => "initial", "item_C" => "initial"}
    initial_jump_state = %{active: false, source_id: nil, target_id: nil}

    new_assigns = %{
      data: initial_data,
      jump_state: initial_jump_state
    }
     Logger.debug("[Parent handle_event] Resetting state: #{inspect(new_assigns)}")
    {:noreply, assign(socket, new_assigns)}
  end
end
