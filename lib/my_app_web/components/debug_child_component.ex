defmodule MyAppWeb.Components.DebugChildComponent do
  use MyAppWeb, :live_component
  require Logger

  @impl true
  def render(assigns) do
    # Log received assigns at component entry
    Logger.debug("[Child render ENTRY] Received assigns: #{inspect(assigns)}")
    Logger.debug("[Child render ENTRY] Received data specifically: #{inspect(assigns[:data])}")
    ~H"""
    <div class="border p-4 mt-4">
      <h2>Debug Child Component</h2>
      <p>Received Data: <%= inspect(@data) %></p>
      <p>Received Show Extra: <%= @show_extra %></p>

      <% # Input field that depends on @data %>
      <% current_value = Map.get(@data, "field1", "default_in_child") %>
      <div class="my-2 p-2 border border-blue-300">
        <label for="child-field1">Field 1 (Should update immediately):</label>
        <input
          type="text"
          id="child-field1"
          name="child_field1"
          value={current_value}
          class="border p-1"
          readonly={true}
        />
        <%# Readonly just for display %>
        <span class="text-xs text-gray-500">(Current value binding: <%= current_value %>)</span>
        <% Logger.debug("[Child render] Rendering input with value: #{inspect(current_value)}") %>
      </div>

      <% # Conditionally rendered block %>
      <%= if @show_extra do %>
        <div class="my-2 p-2 border border-green-300 bg-green-50">
          This is the extra block, shown because show_extra is true.
        </div>
        <% Logger.debug("[Child render] Rendering EXTRA block because show_extra is true") %>
      <% else %>
        <div class="my-2 p-2 border border-red-300 bg-red-50">
          Extra block is hidden.
        </div>
         <% Logger.debug("[Child render] NOT Rendering EXTRA block because show_extra is false") %>
      <% end %>
    </div>
    """
  end
end
